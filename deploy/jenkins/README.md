# CI/CD: Jenkins + SonarCloud

Every push to `main` on GitHub runs the [Jenkinsfile](../../Jenkinsfile) on this laptop:

```
GitHub push ──webhook──> Caddy (/jenkins/github-webhook/) ──> Jenkins
   Tests (parallel):  backend (Maven + Testcontainers + JaCoCo)
                      ML service (pytest + coverage)
                      app (flutter analyze + flutter test)
   SonarCloud:        analysis of all three, waits for the quality gate
   Deploy:            laptop repo -> tested commit, docker compose up -d --build, Caddy reload,
                      waits for the API to be healthy
   APK:               only when mobile/ changed (or FORCE_APK): release APK -> /download/winou.apk
```

Jenkins runs in Docker, next to the Winou stack but as its own compose project (`winou-ci`), and
drives the host's Docker through the mounted socket. Its configuration is code
([casc/jenkins.yaml](casc/jenkins.yaml)): admin account, SonarCloud token and the `winou` job.

The Jenkins UI is only reachable on the laptop: **http://localhost:8081/jenkins**. From the
internet, Caddy forwards GitHub's webhook path and nothing else.

## One-time setup

1. **SonarCloud**: on the project, *Administration → Analysis Method*: turn **off** Automatic
   Analysis. *My Account → Security*: generate a token.
2. **Secrets**: copy `.env.example` to `.env` in this folder, set an admin password and the token.
3. **Start Jenkins** (from this folder; the first build of the image takes a while):
   ```
   docker compose up -d --build
   ```
   Sign in at http://localhost:8081/jenkins as `admin`.
4. **First run**: open the `winou` job and click *Build Now* once. Jenkins learns the repo from
   this run; after it, pushes trigger builds.
5. **GitHub webhook**: repo *Settings → Webhooks → Add webhook*
   - Payload URL: `https://winou.duckdns.org/jenkins/github-webhook/`
   - Content type: `application/json`, event: *Just the push event*.

   GitHub sends a ping; a green tick on the webhook means it reached Jenkins.

## Day to day

- Push to `main`: the build starts within seconds. Follow it at http://localhost:8081/jenkins.
- **Deploy** works on the laptop's copy of the repo (it holds `.env` and `secrets/`). It is left
  alone, and the build marked unstable, if that copy has uncommitted changes or commits not on
  GitHub yet; pushing those commits deploys them.
- *Build with Parameters*: `FORCE_APK` rebuilds the APK, `SKIP_DEPLOY` only tests and analyses.
- Jenkins data (job history, caches, Android SDK) is in the `winou-ci_jenkins_home` volume.
- After editing anything in this folder: `docker compose up -d --build`.
