FROM ruby:2.7

RUN apt-get update && \
    apt-get install -y lftp rsync docker.io docker-compose && \
    rm -rf /var/lib/apt/lists/*

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /updater

COPY Gemfile Gemfile.lock ./
RUN bundle install