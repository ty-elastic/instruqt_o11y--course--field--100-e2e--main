FROM python:3.12.6-slim-bookworm

WORKDIR /app

# COPY requirements.txt .
# RUN --mount=type=cache,target=/root/.cache/pip pip3 install --root-user-action=ignore -r requirements.txt

COPY pos_sim.py .

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["python", "pos_sim.py"]
