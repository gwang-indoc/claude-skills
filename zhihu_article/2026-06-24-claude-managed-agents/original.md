Source: https://claude.com/blog/building-with-claude-managed-agents

Key points from the blog post:
- Claude Managed Agents decouples reasoning engine from execution sandbox
- Old architecture: reasoning + code execution in same container
- Problems: security (credentials next to generated code), slow cold start, fragile state
- New: reasoning layer and sandbox connected via append-only session log
- Security: credentials in external vaults with envelope encryption
- Performance: sandbox startup and reasoning happen in parallel; ~60% median time-to-first-token reduction, >90% at p95
- Observability: every session logs all events (model calls, tool calls, results); resumable
- "Dreaming": agent reviews past sessions to extract patterns and refine behavior
- Three resources: Agents (config), Environments (execution context), Sessions (individual runs)
- Deployment: Anthropic-managed cloud or self-hosted VPC with MCP tunnels
- Real users: Notion (12 hours → 20 minutes), Sentry (weeks not months), Rakuten/Asana/Atlassian (days to deploy)
- Future: teams focus on domain expertise and context management, not harness maintenance
