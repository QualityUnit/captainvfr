#!/usr/bin/env npx tsx

interface TriageDecision {
  shouldTriage: boolean;
  issueNumber: number;
  issueTitle: string;
  reason: string;
  isRetriage: boolean;
  skipReason: string;
}

interface IssuePayload {
  number: number;
  title: string;
  body: string | null;
  pull_request?: unknown;
  user: { login: string; type?: string };
  labels: Array<{ name: string }>;
}

const BOT_SUFFIXES = ['[bot]', '-bot'];

const TRIAGED_LABELS = [
  'agent:plan',
  'agent:implement',
  'needs-human-review',
  'wontfix',
  'duplicate',
  'invalid',
];

const RETRIAGE_LABEL = 'needs-more-info';

export function isBot(login: string, userType?: string): boolean {
  if (userType === 'Bot') return true;
  const lower = login.toLowerCase();
  return BOT_SUFFIXES.some((suffix) => lower.endsWith(suffix));
}

export function isAlreadyTriaged(labels: string[]): boolean {
  return labels.some((label) => TRIAGED_LABELS.includes(label));
}

export function shouldRetriage(labels: string[], eventName: string): boolean {
  if (eventName !== 'edited') return false;
  return labels.includes(RETRIAGE_LABEL);
}

export function evaluate(issue: IssuePayload, eventName: string): TriageDecision {
  const labelNames = issue.labels.map((l) => l.name);

  const base: Pick<TriageDecision, 'issueNumber' | 'issueTitle'> = {
    issueNumber: issue.number,
    issueTitle: issue.title,
  };

  if (issue.pull_request) {
    return {
      ...base,
      shouldTriage: false,
      reason: 'Pull request — not an issue.',
      isRetriage: false,
      skipReason: 'pull_request',
    };
  }

  if (isBot(issue.user.login, issue.user.type)) {
    return {
      ...base,
      shouldTriage: false,
      reason: `Bot-authored issue (${issue.user.login}) — skipping.`,
      isRetriage: false,
      skipReason: 'bot_author',
    };
  }

  const alreadyTriaged = isAlreadyTriaged(labelNames);

  if (eventName === 'edited') {
    if (shouldRetriage(labelNames, eventName)) {
      return {
        ...base,
        shouldTriage: true,
        reason: `Re-triage: issue edited with '${RETRIAGE_LABEL}' label present.`,
        isRetriage: true,
        skipReason: '',
      };
    }
    if (!alreadyTriaged) {
      return {
        ...base,
        shouldTriage: true,
        reason: 'Issue edited but never triaged — proceeding with initial triage.',
        isRetriage: false,
        skipReason: '',
      };
    }
    return {
      ...base,
      shouldTriage: false,
      reason: 'Edit event on already-triaged issue — skipping.',
      isRetriage: false,
      skipReason: 'edit_already_triaged',
    };
  }

  if (alreadyTriaged) {
    return {
      ...base,
      shouldTriage: false,
      reason: 'Issue already has a triage label — skipping.',
      isRetriage: false,
      skipReason: 'already_triaged',
    };
  }

  return {
    ...base,
    shouldTriage: true,
    reason: 'New issue ready for triage.',
    isRetriage: false,
    skipReason: '',
  };
}

if (process.argv.includes('--evaluate')) {
  const eventName = process.env.EVENT_NAME || 'opened';

  let issue: IssuePayload;
  try {
    issue = JSON.parse(process.env.ISSUE_JSON || '{}');
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error(`ERROR: Failed to parse ISSUE_JSON: ${msg}`);
    process.exit(1);
  }

  if (!issue.number) {
    console.error('ERROR: ISSUE_JSON must contain a valid issue number.');
    process.exit(1);
  }

  const decision = evaluate(issue, eventName);
  console.log(JSON.stringify(decision, null, 2));
}

if (process.argv.includes('--self-test')) {
  console.log('Running issue-triage-guard self-test...\n');

  console.assert(isBot('dependabot[bot]') === true, 'dependabot[bot] should be detected as bot');
  console.assert(isBot('renovate-bot') === true, 'renovate-bot should be detected as bot');
  console.assert(isBot('github-actions[bot]', 'Bot') === true, 'Bot user type should be detected');
  console.assert(isBot('yasha-dev1') === false, 'Regular user should not be a bot');
  console.assert(
    isBot('botmaster') === false,
    'User with "bot" in name but no suffix should not match',
  );

  console.assert(isAlreadyTriaged(['agent:plan']) === true, 'agent:plan should indicate triaged');
  console.assert(
    isAlreadyTriaged(['agent:implement']) === true,
    'agent:implement should indicate triaged',
  );
  console.assert(
    isAlreadyTriaged(['needs-human-review']) === true,
    'needs-human-review should indicate triaged',
  );
  console.assert(isAlreadyTriaged(['wontfix']) === true, 'wontfix should indicate triaged');
  console.assert(
    isAlreadyTriaged(['bug', 'enhancement']) === false,
    'Regular labels should not indicate triaged',
  );
  console.assert(isAlreadyTriaged([]) === false, 'No labels should not indicate triaged');

  console.assert(
    shouldRetriage(['needs-more-info'], 'edited') === true,
    'Should re-triage on edit with needs-more-info label',
  );
  console.assert(
    shouldRetriage(['needs-more-info'], 'opened') === false,
    'Should NOT re-triage on open even with needs-more-info',
  );
  console.assert(
    shouldRetriage(['bug'], 'edited') === false,
    'Should NOT re-triage on edit without needs-more-info',
  );

  const newIssue = evaluate(
    {
      number: 1,
      title: 'Bug: login broken',
      body: 'Steps to reproduce...',
      user: { login: 'yasha-dev1' },
      labels: [],
    },
    'opened',
  );
  console.assert(newIssue.shouldTriage === true, 'New issue should be triaged');
  console.assert(newIssue.isRetriage === false, 'New issue is not re-triage');

  const botIssue = evaluate(
    {
      number: 2,
      title: 'Dependency update',
      body: null,
      user: { login: 'dependabot[bot]', type: 'Bot' },
      labels: [],
    },
    'opened',
  );
  console.assert(botIssue.shouldTriage === false, 'Bot issue should be skipped');
  console.assert(botIssue.skipReason === 'bot_author', 'Skip reason should be bot_author');

  const prIssue = evaluate(
    {
      number: 3,
      title: 'Fix: something',
      body: null,
      pull_request: { url: 'https://...' },
      user: { login: 'yasha-dev1' },
      labels: [],
    },
    'opened',
  );
  console.assert(prIssue.shouldTriage === false, 'PR should be skipped');
  console.assert(prIssue.skipReason === 'pull_request', 'Skip reason should be pull_request');

  const triagedIssue = evaluate(
    {
      number: 4,
      title: 'Feature request',
      body: 'Add dark mode',
      user: { login: 'yasha-dev1' },
      labels: [{ name: 'agent:implement' }],
    },
    'opened',
  );
  console.assert(triagedIssue.shouldTriage === false, 'Already triaged issue should be skipped');
  console.assert(
    triagedIssue.skipReason === 'already_triaged',
    'Skip reason should be already_triaged',
  );

  const retriageIssue = evaluate(
    {
      number: 5,
      title: 'Bug report',
      body: 'Updated with more details...',
      user: { login: 'yasha-dev1' },
      labels: [{ name: 'needs-more-info' }],
    },
    'edited',
  );
  console.assert(retriageIssue.shouldTriage === true, 'Re-triage should proceed');
  console.assert(retriageIssue.isRetriage === true, 'Should be flagged as re-triage');

  const editNeverTriaged = evaluate(
    {
      number: 6,
      title: 'Feature',
      body: 'Updated',
      user: { login: 'yasha-dev1' },
      labels: [{ name: 'bug' }],
    },
    'edited',
  );
  console.assert(
    editNeverTriaged.shouldTriage === true,
    'Edit on never-triaged issue should proceed with triage',
  );
  console.assert(editNeverTriaged.isRetriage === false, 'Should not be flagged as re-triage');

  const editAlreadyTriaged = evaluate(
    {
      number: 7,
      title: 'Feature',
      body: 'Updated',
      user: { login: 'yasha-dev1' },
      labels: [{ name: 'agent:implement' }],
    },
    'edited',
  );
  console.assert(
    editAlreadyTriaged.shouldTriage === false,
    'Edit on already-triaged issue should skip',
  );
  console.assert(
    editAlreadyTriaged.skipReason === 'edit_already_triaged',
    'Skip reason should be edit_already_triaged',
  );

  console.log('\n✔ All self-tests passed.');
}
