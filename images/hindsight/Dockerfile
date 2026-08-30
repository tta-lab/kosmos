# Hindsight 0.9.2 with the multilingual MiniLM model baked into the image.
# The upstream image already contains the API, control plane, local ML
# dependencies, tiktoken cache, and its non-root `hindsight` runtime user.
FROM ghcr.io/vectorize-io/hindsight:0.9.2@sha256:84ab276b8f501546deb6ea9c64a57291718b4e16a59dd9e02a02fdd5adfe9028

ARG EMBEDDING_MODEL=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
ARG EMBEDDING_MODEL_REVISION=e8f8c211226b894fcb81acc59f3b34ba3efd5f42
ARG EMBEDDING_MODEL_PATH=/opt/hindsight-models/paraphrase-multilingual-MiniLM-L12-v2

ENV HF_HOME=/home/hindsight/.cache/huggingface \
    TRANSFORMERS_CACHE=/home/hindsight/.cache/huggingface \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1 \
    CUDA_VISIBLE_DEVICES=""

# The upstream final stage runs as `hindsight`. Put the cache at the same path
# used by the Kubernetes workload, then restore the non-root user explicitly.
USER root
RUN mkdir -p /home/hindsight/.cache/huggingface \
    /opt/hindsight-models \
    && chown -R hindsight:hindsight /home/hindsight/.cache /opt/hindsight-models

USER hindsight
RUN HF_HUB_OFFLINE=0 TRANSFORMERS_OFFLINE=0 \
    /app/api/.venv/bin/python - "$EMBEDDING_MODEL" "$EMBEDDING_MODEL_REVISION" "$EMBEDDING_MODEL_PATH" <<'PY'
import sys

from sentence_transformers import SentenceTransformer

model_name, revision, model_path = sys.argv[1:]
model = SentenceTransformer(model_name, revision=revision, device="cpu")
dimension = model.get_sentence_embedding_dimension()
if dimension != 384:
    raise SystemExit(f"unexpected embedding dimension for {model_name}: {dimension}")
model.save(model_path)
offline_model = SentenceTransformer(model_path, device="cpu", local_files_only=True)
if offline_model.get_sentence_embedding_dimension() != 384:
    raise SystemExit(f"saved model at {model_path} has an unexpected embedding dimension")
print(f"saved {model_name}@{revision} to {model_path} ({dimension} dimensions on CPU)")
PY

LABEL org.opencontainers.image.title="kosmos-hindsight" \
      org.opencontainers.image.version="0.1.1" \
      org.opencontainers.image.description="Hindsight 0.9.2 with an offline multilingual MiniLM embedding cache" \
      org.opencontainers.image.source="https://github.com/tta-lab/kosmos" \
      org.opencontainers.image.embedding-model="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2" \
      org.opencontainers.image.embedding-model-revision="e8f8c211226b894fcb81acc59f3b34ba3efd5f42"
