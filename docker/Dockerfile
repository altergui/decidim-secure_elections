# Runtime image for a Decidim application using decidim-secure_elections.
#
# Both toolchains are pinned deliberately: Decidim 0.33 requires Ruby 3.4.7 and
# Node 24.18.0, and Shakapacker shells out to `node` from a plain `sh`, so Node
# must be resolvable on the system PATH — not only via a shell-init version
# manager. Installing it to /usr/local is what makes asset compilation work in
# a non-interactive container.

ARG RUBY_VERSION=3.4.7
FROM ruby:${RUBY_VERSION}-slim

ARG NODE_VERSION=24.18.0

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    RAILS_LOG_TO_STDOUT=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git curl ca-certificates xz-utils \
      libpq-dev postgresql-client \
      libvips42 imagemagick \
      libicu-dev libyaml-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Node from the official tarball, straight onto the system PATH.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) node_arch='x64' ;; \
      arm64) node_arch='arm64' ;; \
      *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
      -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
      --exclude CHANGELOG.md --exclude LICENSE --exclude README.md; \
    rm /tmp/node.tar.xz; \
    node --version; npm --version

WORKDIR /app

# Dependency layers first so application changes do not invalidate them.
COPY Gemfile Gemfile.lock* ./
RUN bundle config set --local without 'development test' \
    && bundle install --jobs 4 --retry 3

COPY package.json package-lock.json* ./
RUN npm install --omit=dev --no-audit --no-fund

COPY . .

RUN bundle exec rake assets:precompile

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
