const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const glob = require('glob');

// Get the latest version of the Lambda layer
function getLatestLayerVersion() {
  try {
    const layerName = process.env.LAMBDA_LAYER_NAME || 'nodejs-22x-dev';
    const command = `aws lambda list-layer-versions --layer-name ${layerName} --query "LayerVersions[0].LayerVersionArn" --output text`;
    const result = execSync(command, { encoding: 'utf-8' }).trim();
    
    if (!result) {
      throw new Error('No layer version found');
    }
    
    console.log('Found latest layer version:', result);
    return result;
  } catch (error) {
    console.error('Error getting latest layer version:', error.message);
    process.exit(1);
  }
}

// Update the template.yml files
function updateTemplateFiles(newArn) {
  try {
    const templateFiles = glob.sync('**/template.yml');
    console.log(`Found ${templateFiles.length} template files to process`);
    
    let updatedCount = 0;
    
    templateFiles.forEach(file => {
      console.log(`Processing ${file}...`);
      let content = fs.readFileSync(file, 'utf-8');
      
      const layerArnKey = process.env.LAYER_ARN_KEY || 'TSLayerArn';
      if (content.includes(`${layerArnKey}:`)) {
        const originalContent = content;

        content = content.replace(
          new RegExp(`(${layerArnKey}:\\s*Type:\\s*String\\s*Default:\\s*)[^\\s\\n]*`, 'm'),
          `$1${newArn}`
        );

        if (content !== originalContent) {
          fs.writeFileSync(file, content);
          console.log(`✓ Updated ${file}`);
          updatedCount++;
        } else {
          console.log(`- No changes needed in ${file}`);
        }
      } else {
        console.log(`- Skipping ${file} (no ${layerArnKey} found)`);
      }
    });
    
    console.log(`\nSummary: Updated ${updatedCount} out of ${templateFiles.length} template files`);
  } catch (error) {
    console.error('Error updating template files:', error.message);
    process.exit(1);
  }
}

// Main execution
console.log('Starting Lambda layer update process...\n');
const newArn = getLatestLayerVersion();
updateTemplateFiles(newArn);
console.log('\nUpdate process complete!'); 