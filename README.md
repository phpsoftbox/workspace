# Workspace

Docker-обвязка для локальной разработки PhpSoftBox-приложений.

## Установка Через Installer

`phpsoftbox` - отдельный installer/launcher для Workspace и PhpSoftBox-приложений. Его стоит держать в отдельном репозитории: жизненный цикл installer не должен быть связан с docker-обвязкой или skeleton-приложением.

MVP installer работает через локальные `php-cli`, `ext-mbstring` и Composer. Если локального PHP нет, используй ручную установку ниже: приложение и зависимости будут ставиться уже внутри Docker-контейнеров Workspace.

Установка через shell script:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/phpsoftbox/installer/master/install.sh)"
```

Установка через Composer:

```bash
composer global require \
  phpsoftbox/installer:dev-master \
  phpsoftbox/cli-app:dev-master \
  phpsoftbox/error-formatter:dev-master \
  --prefer-stable
```

После установки `phpsoftbox workspace:install [dir]` можно запускать из любой директории. Все остальные команды `phpsoftbox` запускаются из корня Workspace: там должны лежать `compose.yml`, `.env` и `.workspace.ini`.

Shell installer может дополнительно создать короткий alias `psb -> phpsoftbox`, но основной Composer bin называется полным именем, чтобы не конфликтовать с другими пакетами.

Если после установки команда `phpsoftbox` не находится, добавь Composer global bin directory в `PATH`:

```bash
export PATH="$(composer global config bin-dir --absolute):$PATH"
```

## Быстрый Старт С Installer

```bash
phpsoftbox workspace:install Workspace
cd Workspace
phpsoftbox workspace:init
phpsoftbox new backend
phpsoftbox init
phpsoftbox up
phpsoftbox vite-dev
```

По умолчанию `make up` читает профили из `.workspace.ini`. Базовый минимальный набор: `web cli`.

Приложение будет доступно на `http://localhost:8080`, Vite dev server - на `http://localhost:5173`.

## Ручная Установка

Этот путь не требует локального PHP. Нужны `git`, `make`, Docker и Docker Compose.

```bash
git clone https://github.com/phpsoftbox/workspace.git Workspace
cd Workspace
rm -rf .git

cp .env.example .env
cp .workspace.ini.example .workspace.ini

git clone https://github.com/phpsoftbox/app-backend.git local/backend

make init
make up
make vite-dev
```

Workspace - это одноразовый scaffold рабочей среды, а не git checkout для регулярных обновлений. После установки его можно спокойно менять под проект: редактировать compose/config, добавлять сервисы, локальные директории и override-файлы.

`make init`, `make composer-install`, `make yarn-install` и `make vite-dev` выполняются внутри Docker-окружения Workspace, поэтому локальные `php`, `composer`, `node` и `yarn` для этого сценария не нужны.

`make init` выполняет первичную подготовку приложения: генерирует `APP_KEY` в
`.env`, если он ещё не задан, запускает `composer install` и `yarn install`.
Эту команду нужно выполнить до первого `make up`, иначе web-профиль может
стартовать раньше появления `vendor/autoload.php`.

## Структура

```text
Workspace/
  compose.yml
  .workspace.ini.example
  .env.example
  Makefile
  docker/
    php/
      Dockerfile
      conf.d/
    nginx/
      default.conf
    mariadb/
      my.cnf
      init/
  local/
    backend/
```

`local/<project>` предназначен для рабочих копий проектов: backend, frontend или дополнительных микросервисов. Содержимое `local/*` игнорируется, чтобы Workspace оставался отдельным репозиторием и не смешивался с кодом приложений.

`phpsoftbox new backend` создает новый backend-сервис в `local/backend` из AppBackend skeleton. Имя аргумента становится именем директории внутри `local`.

`phpsoftbox new <service>` и команды запуска окружения выполняются из корня Workspace. Это делает контекст однозначным: installer работает с текущими `.env`, `.workspace.ini`, `compose.yml` и папкой `local`.

## Профили

- `web`: `nginx`, `php-fpm`.
- `cli`: `php-cli` для Composer, PHPUnit, PSB CLI и одноразовых команд.
- `mariadb`: MariaDB с healthcheck и volume.
- `mongodb`: MongoDB с healthcheck и volume.
- `redis`: Redis.
- `mail`: Mailpit.
- `pdf` / `gotenberg`: Gotenberg для генерации PDF и офисных документов.
- `queue`: queue worker, когда проект подключает очереди.
- `scheduler`: long-running scheduler process, когда проект подключает планировщик.
- `websocket`: Pushr WebSocket server.
- `tg-bot-polling`: Telegram bot long polling process.

Traefik не входит в базовую обвязку. Для локали reverse proxy подхватывается через доменные маршруты `dispatcher`, `tenant.*` и `ws`.

## Настройки Профилей

`.workspace.ini.example` хранит пример дефолтного набора профилей:

```ini
[profiles]
default_profiles = web cli
```

Для локального проекта нужно создать `.workspace.ini`; он игнорируется git:

```ini
[profiles]
default_profiles = web cli mariadb mongodb redis mail pdf queue scheduler websocket tg-bot-polling gotenberg
```

Разовый запуск можно переопределить через переменную Make:

```bash
make up PROFILES="web cli mariadb"
make profiles
```

## Session Cookies

В `.env.example` используется `APP_SESSION_SECURE=auto`: на HTTPS session cookie будет `Secure`, на локальном `http://localhost` флаг `Secure` отключится, чтобы сессии работали без reverse proxy. Для staging/production и любых HTTPS-окружений ставь `APP_SESSION_SECURE=always`.

## Shell

PHP-контейнеры собираются с locale `ru_RU.UTF-8`, поэтому кириллица в выводе
CLI-команд не ломается.

Для `make php-shell` подключается bash completion для проектного `psb`:

```bash
php psb <TAB>
php psb auth:<TAB>
```

## Примеры

```bash
make up
make up PROFILES="web cli mariadb mongodb redis mail pdf"
make up PROFILES="web cli mariadb redis queue scheduler websocket"
make up PROFILES="web cli mariadb redis tg-bot-polling"
make down
make down-clear
```

Installer-обертки над Makefile:

```bash
phpsoftbox up
phpsoftbox down
phpsoftbox build
phpsoftbox ps
phpsoftbox logs
phpsoftbox shell
```

Все эти команды запускаются из корня Workspace. Единственное исключение - `phpsoftbox workspace:install [dir]`, потому что она как раз создает директорию Workspace.

## Команды

```bash
make php-shell
make -- php-run php -v
make init
make composer-install
make composer-update
make test
make cs-check
make yarn-build
make vite-dev
```

`vite-dev` запускает Vite внутри `php-fpm` от проектного пользователя, поэтому перед ним должен быть поднят `web` profile. Это сохраняет корректного владельца для `node_modules`, `yarn.lock` и файлов сборки в bind-mounted проекте.

`scheduler` profile запускает `php psb schedule:work`: это foreground daemon,
который выполняет проверку расписания раз в минуту. После изменения файлов
`config/schedule/*.php` перезапусти scheduler service.

Команды process-сервисов настраиваются через `.env`:

```bash
QUEUE_COMMAND="php psb queue:listen"
SCHEDULER_COMMAND="php psb schedule:work"
WEBSOCKET_COMMAND="php psb pushr:serve:registry --host=0.0.0.0 --port=8080 --max-skew=300"
TG_BOT_POLLING_COMMAND="php psb telegram:poll"
```

Для multi-tenant проектов эти команды обычно переопределяются на проектные,
например `tenant:pushr:serve:registry --tenant=all` или `tenant:telegram:poll --tenant=all`.
