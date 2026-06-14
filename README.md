## Backend Development

To run the backend API with hot reload using Docker:

```bash
docker compose up api
```

Or, to run it in the background (detached mode):

```bash
docker compose up -d api
```

The `api` service mounts `./backend` into the container and runs `npm run dev`, so saving files under `backend/` will automatically trigger a reload inside the running container.
