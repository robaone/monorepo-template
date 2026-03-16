# Testing the Deploy Selected Domains Workflow

## Setup
1. Make sure you're on the main branch
2. Create some test tags to simulate different versions:
   ```bash
   git tag v1.0.0
   git tag v1.1.0
   git tag v2.0.0
   git push origin --tags
   ```

## Test Cases

### Test 1: Deploy Single Domain
- **Version**: `1.0.0`
- **Domains**: `delivery-ts`
- **Expected**: Only delivery-ts should be deployed from v1.0.0

### Test 2: Deploy Multiple Domains
- **Version**: `1.1.0`
- **Domains**: `delivery-ts,data-ingestion`
- **Expected**: Both domains should be deployed from v1.1.0

### Test 3: Deploy with Different Version
- **Version**: `2.0.0`
- **Domains**: `data-ingestion`
- **Expected**: Only data-ingestion should be deployed from v2.0.0

## How to Test
1. Go to GitHub Actions in your practice repository
2. Select "Deploy Selected Domains" workflow
3. Click "Run workflow"
4. Fill in the inputs and run
5. Check the logs to verify:
   - The correct version is being checked out
   - The correct domains are being deployed
   - The deployment messages show the right version

## Expected Log Output
You should see logs like:
```
Deploying delivery-ts to prod
Version: 1.0.0
AWS Account: [your-account]
AWS Region: us-east-1
Deployment completed successfully!
```

## Rollback Simulation
To test rollback functionality:
1. Deploy version `2.0.0` first
2. Then deploy version `1.0.0` to simulate a rollback
3. Verify that the older version is actually checked out and deployed


