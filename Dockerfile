# ─────────────────────────────────────────────────────────────
# Stage 1: Build Flutter Web
# ─────────────────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Cache pub dependencies separately from source
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Copy source
COPY . .

# Enable web platform support (idempotent: won't overwrite existing files)
# Required because the repo doesn't include generated web/ binary assets
RUN flutter create . --platforms web --project-name amap_app

# Generate code: Freezed, Riverpod, json_serializable, GoRouter
# This produces all *.g.dart and *.freezed.dart files at build time
RUN dart run build_runner build --delete-conflicting-outputs

# Build-time secrets injected as Docker build args
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY

RUN flutter build web --release \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}

# ─────────────────────────────────────────────────────────────
# Stage 2: Serve with Nginx (Alpine — ~25 MB)
# ─────────────────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Remove default config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom Nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the built web app
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost/index.html || exit 1

CMD ["nginx", "-g", "daemon off;"]
