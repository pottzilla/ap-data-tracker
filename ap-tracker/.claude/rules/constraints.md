## Constraints and Non-Negotiables

- Never hardcode credentials -- all via .env
- Never commit .env or credentials.txt to GitHub
- All Graph API calls must handle token expiry and re-authenticate automatically
- All Graph API calls must implement exponential backoff retry on rate limiting
- All modules must include docstrings
- All logging via Python logging module -- no print statements in production code
- Claude enrichment prompt stored as module-level constant -- never embedded in function logic
- JSON parse from Claude must be wrapped in try/except with safe defaults
- PowerShell scripts must prompt for passwords using Read-Host -AsSecureString -- never hardcoded
