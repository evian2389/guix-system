
# What is this?
* Description of current working plan to make things done

#  Prerequisite
* check README.md - Overview and Structure


# TODO
* Make emacs org usable.
** Major working dir : src/raynet-guix/users/orka/files/emacs
** Apply and validatioan :
  - chnages to src/raynet-guix/users/orka/files/.config/emacs/Emacs.org
  - apply it : src/raynet-guix/users/orka/files/.config/emacs/tangle.sh
  - if guix package changed : use 'make reconfigure-home' on Makefile in project root.
*** Current focus :
    - gather project related command to SPC-p
    - Adopt emacs config of src/raynet-guix/users/orka/files/.config/emacs/20250915140606-dotfiles.org to src/raynet-guix/users/orka/files/.config/emacs/Emacs.org
    - apply changes with tangle.sh then check emacs error (emacs -nw --debug-init).
* Installing emacs pacakges.
  - use src/raynet-guix/home-services/emacs.scm (use 'guix search [package]' to check if the package is available)

# Stock-Trading Pipeline — Post Guix Reconfigure TODOs

After running `make reconfigure-home` from ~/guix-system, the following tools will be available:
nats-server, redis, postgresql, timescaledb, podman-compose

## 1. Apply guix home update
```
cd ~/guix-system && make reconfigure-home
```

## 2. Verify tools installed
```
nats-server --version
redis-server --version
psql --version
podman-compose --version
```

## 3. Initialize PostgreSQL data directory
```
initdb -D ~/.local/share/postgresql
```

## 4. Start infrastructure services (local, no containers)
```
# Terminal 1 — NATS
nats-server -js

# Terminal 2 — Redis
redis-server

# Terminal 3 — PostgreSQL
pg_ctl -D ~/.local/share/postgresql -l ~/.local/share/postgresql/logfile start
```

## 5. Apply DB schema
```
createdb stocktrading
psql stocktrading < ~/work/stock-trading/infra/postgres/init.sql
```

## 6. Run unit tests (confirm all pass after env change)
```
cd ~/work/stock-trading/services/analyzer && uv run --extra dev pytest
cd ~/work/stock-trading/services/evaluator && uv run --extra dev pytest
cd ~/work/stock-trading/services/collector && CGO_ENABLED=0 go test -v ./...
```

## 7. Run the pipeline end-to-end
```
# Set env vars
export NATS_URL=nats://localhost:4222
export DATABASE_URL=postgresql://localhost/stocktrading
export ANTHROPIC_API_KEY=...
export NEWSAPI_KEY=...

# Terminal A — Go collector
cd ~/work/stock-trading/services/collector && go run ./cmd/collector

# Terminal B — Python analyzer
cd ~/work/stock-trading/services/analyzer && uv run python -m analyzer.main

# Terminal C — Python evaluator
cd ~/work/stock-trading/services/evaluator && uv run python -m evaluator
```

## 8. (Optional) Use podman-compose instead of manual starts
```
cd ~/work/stock-trading/infra && podman-compose up
```
Note: docker-compose.yml uses timescale/timescaledb image which needs the TimescaleDB
extension enabled via shared_preload_libraries in postgresql.conf — prefer step 4-5 for
local native setup.

---

# record current status
* record current working status here for later use.
  - applied emacs-meow (dw-meow.el)
  - fixed syntax error in dw-meow.el (extra parenthesis and void variable meow-leader-keymap)

