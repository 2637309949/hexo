FROM nginx:stable-alpine

RUN echo "http://mirrors.aliyun.com/alpine/v3.6/main/" > /etc/apk/repositories
RUN apk update && apk add tzdata \
    && rm -f /etc/localtime \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

WORKDIR /usr/share/nginx/html
RUN mkdir -p /etc/nginx/conf.d/
RUN mkdir -p /usr/share/nginx/html/inspiration

COPY nginx.conf /etc/nginx/conf.d/nginx.conf
COPY public /usr/share/nginx/html
COPY public /usr/share/nginx/html/inspiration

EXPOSE 80
CMD [ "nginx", "-g", "daemon off;" ]
