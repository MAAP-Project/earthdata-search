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

## How to Configure DNS for `search.*.maap-project.org`

`https://search.uat.maap-project.org` and `https://search.ops.maap-project.org` are already configured in UAH's Route 53 DNS Hosted Zones, pointing to a cloudfront distribution for their respective buckets.

The steps for configuring a new subdomain, say for `search.uat.maap-project.org`, for future reference are as follows:

1. The S3 bucket `earthdata-search-maap-uat` has static website hosting enabled and permissions set for public access.
2. There is a validated SSL Certificate for `*.uat.maap-project.org`.
3. There is an AWS Cloudfront Distribution with:
    * Origin Name points to the bucket URL: `earthdata-search-maap-uat.s3-website-us-west-2.amazonaws.com`
    * Alternate Domain Names (CNAMEs) as `search.uat.maap-project.org`
    * SSL Certificate referencing the appropriate SSL Certificate `*.uat.maap-project.org (XXX-XXXX-XXXX-XXX-UUID)`
4. There is an `A` name record in the `maap-project.org` Route53 hosted zone which points to the Cloudfront Distribution URL as an `Alias`, e.g. `d31rmtr53wrle7.cloudfront.net`.

The Cloudfront Distribution and SSL Certificate can be configured in either the UAH AWS account or the destination GCC account. UAH AWS maintains the `maap-project.org` Route53 Hosted Zone so step 4 must be configured in the UAH account.

