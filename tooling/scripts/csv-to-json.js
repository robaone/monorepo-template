#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Check if input file is provided
if (process.argv.length !== 3) {
    console.error('Usage: node csv2json.js <input_csv_file>');
    process.exit(1);
}

const inputFile = process.argv[2];

// Check if input file exists
if (!fs.existsSync(inputFile)) {
    console.error(`Error: File '${inputFile}' not found`);
    process.exit(1);
}

try {
    // Read the CSV file
    const csvContent = fs.readFileSync(inputFile, 'utf-8');
    
    // Split into lines and remove empty lines
    const lines = csvContent.split('\n').filter(line => line.trim());
    
    if (lines.length < 2) {
        console.error('Error: CSV file must have at least a header row and one data row');
        process.exit(1);
    }

    // Get headers from first line
    const headers = lines[0].split(',').map(header => 
        header.trim().replace(/^["']|["']$/g, '')
    );

    // Process data rows
    const jsonData = lines.slice(1).map(line => {
        // Handle quoted fields with commas inside them
        const values = [];
        let currentValue = '';
        let insideQuotes = false;
        
        for (let i = 0; i < line.length; i++) {
            const char = line[i];
            
            if (char === '"') {
                insideQuotes = !insideQuotes;
            } else if (char === ',' && !insideQuotes) {
                values.push(currentValue.trim().replace(/^["']|["']$/g, ''));
                currentValue = '';
            } else {
                currentValue += char;
            }
        }
        values.push(currentValue.trim().replace(/^["']|["']$/g, ''));

        // Create object with headers as keys
        const obj = {};
        headers.forEach((header, index) => {
            obj[header] = values[index] || '';
        });
        
        return obj;
    });

    // Output JSON
    console.log(JSON.stringify(jsonData, null, 2));
} catch (error) {
    console.error('Error processing file:', error.message);
    process.exit(1);
} 