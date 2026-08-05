FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system checktap \
    && useradd --system --gid checktap --home-dir /app --shell /usr/sbin/nologin checktap

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=checktap:checktap . .
RUN chmod +x /app/entrypoint.sh

USER checktap

EXPOSE 8000
ENTRYPOINT ["/app/entrypoint.sh"]
