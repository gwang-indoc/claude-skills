Source: https://claude.com/blog/agent-identity-access-model

Agent Identity Access Model blog post by Anthropic/Claude Tag.

Core: Claude Tag introduces an agent identity access model where AI agents operate with their own workspace-level service accounts rather than borrowing individual user permissions.

Key problems with old model:
1. Autonomous agents work independently after users log off - no "current user" to borrow from
2. Multiplayer teams create ambiguity - multiple people directing same agent
3. Borrowing user credentials = agent gets access to everything the user can access (private messages, personal files, etc.)

Solution:
- Claude operates under its own service accounts
- Posts as "Claude app" in Slack, uses dedicated GitHub app credentials, accesses warehouses via service accounts
- Eliminates personal credentials

Permission Architecture:
- Baseline identity at workspace level (inherited by all channels)
- Channel-level overrides for specialized access (engineering channel gets GitHub/warehouse, legal channel does not)
- Private channels get distinct identities; public channels share workspace-level identity

Security:
- Outbound traffic restricted to admin-approved hosts
- All actions logged under service accounts in each system's own audit trail
- Revoking workspace identity removes all agent access instantly

Best practice: start with generous access, refine based on audit trails.
