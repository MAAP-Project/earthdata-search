# [MAAP Earthdata Search](https://search.maap-project.org)

**Please note:** This is a forked version of [github.com/nasa/earthdata-search](https://github.com/nasa/earthdata-search).

The original README is still included in this repo under
[`README_original.md`](./README_original.md).

You should follow the instructions there for local setup and running the application locally.

For MAAP, we just require a static deployment of the files generated under the `/static` by the build step:

```
npm run build
```


These files are then deployed to S3 using:

```bash
# For deployment to MAAP SIT (systems integration)
serverless client deploy --stage maap-sit
# For deployment to MAAP PROD
serverless client deploy --stage maap
```

The earthdata-search-maap bucket is already configured for static website hosting.

