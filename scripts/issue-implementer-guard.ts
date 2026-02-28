#!/usr/bin/env npx tsx

interface Issue {
  number: number;
  title: string;
  body: string;
  labels: Array<{ name: string }>;
  user: { login: string };
}

interface ImplementerDecision {
  shouldImplement: boolean;
  issueNumber: number;
  issueTitle: string;
  branchName: string;
  reason: string;
  existingPR: number | null;
  blockedLabels: string[];
}

const BLOCKING_LABELS = ['agent:skip', 'wontfix', 'duplicate', 'invalid'];
const MAX_REVIEW_CYCLES = 3;

export function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40);
}

export function deriveBranchName(issueTitle: string, issueNumber: number): string {
  const slug = slugify(issueTitle);
  return `cf/${slug}-${issueNumber}`;
}

export async function findExistingPR(issueNumber: number): Promise<number | null> {
  try {
    const { execSync } = await import('child_process');
    const result = execSync(
      `gh issue view ${issueNumber} --json comments --jq '.comments[] | select(.body | contains("<!-- issue-implementer: #${issueNumber} -->")) | .body'`,
      { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'ignore'] }
    );
    if (result.trim()) {
      const match = result.match(/#(\d+)/);
      return match ? parseInt(match[1], 10) : null;
    }
  } catch {}
  return null;
}

export async function evaluate(issue: Issue): Promise<ImplementerDecision> {
  const hasImplementLabel = issue.labels.some(l => l.name === 'agent:implement');
  
  if (!hasImplementLabel) {
    return {
      shouldImplement: false,
      issueNumber: issue.number,
      issueTitle: issue.title,
      branchName: '',
      reason: 'Missing agent:implement label',
      existingPR: null,
      blockedLabels: [],
    };
  }

  const blockedLabels = issue.labels
    .map(l => l.name)
    .filter(name => BLOCKING_LABELS.includes(name));

  if (blockedLabels.length > 0) {
    return {
      shouldImplement: false,
      issueNumber: issue.number,
      issueTitle: issue.title,
      branchName: '',
      reason: `Blocked by labels: ${blockedLabels.join(', ')}`,
      existingPR: null,
      blockedLabels,
    };
  }

  const existingPR = await findExistingPR(issue.number);
  if (existingPR) {
    return {
      shouldImplement: false,
      issueNumber: issue.number,
      issueTitle: issue.title,
      branchName: '',
      reason: `PR #${existingPR} already exists`,
      existingPR,
      blockedLabels: [],
    };
  }

  const branchName = deriveBranchName(issue.title, issue.number);

  return {
    shouldImplement: true,
    issueNumber: issue.number,
    issueTitle: issue.title,
    branchName,
    reason: 'Ready for implementation',
    existingPR: null,
    blockedLabels: [],
  };
}

export async function evaluateReviewFix(
  prNumber: number,
  cycle: number
): Promise<ImplementerDecision> {
  if (cycle > MAX_REVIEW_CYCLES) {
    return {
      shouldImplement: false,
      issueNumber: 0,
      issueTitle: '',
      branchName: '',
      reason: `Review-fix cycle limit exceeded (max ${MAX_REVIEW_CYCLES})`,
      existingPR: prNumber,
      blockedLabels: [],
    };
  }

  try {
    const { execSync } = await import('child_process');
    const prData = JSON.parse(
      execSync(`gh pr view ${prNumber} --json number,title,headRefName,state`, {
        encoding: 'utf-8',
      })
    );

    if (prData.state !== 'OPEN') {
      return {
        shouldImplement: false,
        issueNumber: 0,
        issueTitle: prData.title,
        branchName: prData.headRefName,
        reason: `PR is ${prData.state}`,
        existingPR: prNumber,
        blockedLabels: [],
      };
    }

    return {
      shouldImplement: true,
      issueNumber: 0,
      issueTitle: prData.title,
      branchName: prData.headRefName,
      reason: `Review-fix cycle ${cycle}`,
      existingPR: prNumber,
      blockedLabels: [],
    };
  } catch (err) {
    return {
      shouldImplement: false,
      issueNumber: 0,
      issueTitle: '',
      branchName: '',
      reason: `Failed to fetch PR data: ${err}`,
      existingPR: prNumber,
      blockedLabels: [],
    };
  }
}

async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--self-test')) {
    console.log('Running self-tests...');
    
    const testSlug = slugify('Add new feature for user authentication');
    if (testSlug !== 'add-new-feature-for-user-authentication') {
      throw new Error(`slugify test failed: ${testSlug}`);
    }

    const testBranch = deriveBranchName('Fix bug in payment flow', 42);
    if (testBranch !== 'cf/fix-bug-in-payment-flow-42') {
      throw new Error(`deriveBranchName test failed: ${testBranch}`);
    }

    console.log('✅ All tests passed');
    process.exit(0);
  }

  if (args.includes('--evaluate')) {
    const prNumber = process.env.PR_NUMBER;
    const reviewFixCycle = process.env.REVIEW_FIX_CYCLE;

    let decision: ImplementerDecision;

    if (prNumber && reviewFixCycle) {
      decision = await evaluateReviewFix(parseInt(prNumber, 10), parseInt(reviewFixCycle, 10));
    } else {
      const issueJson = process.env.ISSUE_JSON;
      if (!issueJson) {
        console.error('ISSUE_JSON environment variable not set');
        process.exit(1);
      }

      const issue: Issue = JSON.parse(issueJson);
      decision = await evaluate(issue);
    }

    const fs = await import('fs');
    fs.writeFileSync('guard-decision.json', JSON.stringify(decision, null, 2));
    console.log(JSON.stringify(decision, null, 2));
    process.exit(0);
  }

  console.error('Usage: issue-implementer-guard.ts [--evaluate|--self-test]');
  process.exit(1);
}

main();
