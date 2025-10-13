###########################################################
# Base Python image. Set shared environment variables.
FROM python:3.14-alpine AS base
ENV PYTHONUNBUFFERED=1 \
    PYSETUP_PATH="/opt/pysetup" \
    VENV_PATH="/opt/pysetup/.venv" \
    UV_PYTHON_DOWNLOADS=never \ 
    UV_COMPILE_BYTECODE=1 \
    PYTHONUNBUFFERED=1

ENV PATH="$VENV_PATH/bin:$PATH"

###########################################################
# Builder stage. Build dependencies.
FROM base AS builder
RUN apk add --no-cache \
        build-base \
        curl \
        netcat-openbsd \
        bash

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv ~/.local/bin/uv /usr/local/bin/ && \
    uv --version

# Create virtual environment and install dependencies
WORKDIR $PYSETUP_PATH
RUN uv venv $VENV_PATH
COPY ./uv.lock ./pyproject.toml ./
RUN uv sync

###########################################################
# Production stage. Copy only runtime deps.
FROM base AS production

COPY --from=builder $VENV_PATH $VENV_PATH

COPY --chmod=755 entrypoint.sh /

# Create user with the name uvuser
RUN addgroup -g 1500 uvuser && \
    adduser -D -u 1500 -G uvuser uvuser

COPY --chown=uvuser:uvuser . /code
USER uvuser
WORKDIR /code

EXPOSE 8000
ENTRYPOINT [ "/entrypoint.sh" ]