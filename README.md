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
serverless client deploy --stage maap<-env>

# UAH AWS
serverless client deploy --stage maap 
# GCC Dev/UAT
serverless client deploy --stage maap-uat
# GCC Prod/Ops
serverless client deploy --stage maap-prod
```

The earthdata-search-maap (UAH), earthdata-search-maap-uat, earthdata-search-maap-prod buckets are already configured for static website hosting.

## DNS Configuration

search.uat.maap-project.org and search.ops.maap-project.org should already be properly configured in UAH Route 53 DNS Hosted Zones to point to a cloudfront distribution for their respective buckets. The steps to configuring a new subdomain, say for `search.uat.maap-project.org`, for future reference are as follows:

* The corresponding S3 bucket, earthdata-search-maap-uat, has static website hosting enabled and permissions set for public access.
* There is a validated SSL Certificate for `*.uat.maap-project.org`
* There is a cloudfront distribution with Origin Name pointing to the bucket URL and configured with the SSL certificate
* There is an `A` name record in the maap-project.org Route53 hosted zone which points to the cloudfront distribution URL as an `Alias`

