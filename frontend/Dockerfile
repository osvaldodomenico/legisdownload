FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app
COPY shift_downloads/pubspec.yaml shift_downloads/pubspec.lock ./shift_downloads/
RUN cd shift_downloads && flutter pub get
COPY shift_downloads/ ./shift_downloads/
RUN cd shift_downloads && flutter clean && flutter build web --dart-define=API_BASE_URL=https://legisdownload-api.shiftworks.app.br/api --release

FROM nginx:alpine
COPY --from=builder /app/shift_downloads/build/web /usr/share/nginx/html
COPY nginx-web.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
