FROM alpine

RUN apk update
RUN apk upgrade

RUN apk add curl-dev ruby-dev build-base
RUN apk add ruby ruby-io-console ruby-bundler

RUN apk add git

# set the code directory
ENV CODE_DIR /code
WORKDIR $CODE_DIR

COPY --chown=1000:1000 . $CODE_DIR

RUN ls

# RUN bundle install

# RUN gem build anthos_deployer.gemspec

RUN gem install bundler --no-rdoc --no-ri

RUN gem install anthos_deployer-0.1.0.gem --no-rdoc --no-ri

RUN anthos_deployer --config=./deployment.yaml

# RUN bundle exec rake

# RUN make build
