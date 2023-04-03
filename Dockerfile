FROM ruby:2.7.1-alpine

RUN apk --no-cache add cmake g++ make openssl-dev

RUN mkdir /app
WORKDIR /app
ADD . /app

RUN bundle install && bundle exec rake install

RUN addgroup -S appgroup && adduser -S appuser -G appgroup -u 1000
USER appuser

ENTRYPOINT ["fastly2git"]
