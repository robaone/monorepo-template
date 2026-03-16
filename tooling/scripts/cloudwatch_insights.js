#!/usr/bin/env node

const { spawn } = require('child_process');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');

/**
 * Configuration class for CloudWatch Insights queries
 */
class CloudWatchConfig {
  constructor() {
    this.env = this.determineEnvironment();
    this.defaultLimit = 100;
    this.maxBatchSize = 10000;
    this.defaultTimeRange = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    this.pollInterval = 1000; // 1 second
    this.sortOrder = '@timestamp desc';
  }

  determineEnvironment() {
    const awsProfile = process.env.AWS_PROFILE || '';
    if (awsProfile.includes('dev')) return 'dev';
    if (awsProfile.includes('uat')) return 'uat';
    if (awsProfile.includes('prod')) return 'prod';
    return 'prod'; // default
  }

  getLogGroupName(lambdaName) {
    if (lambdaName.startsWith('/')) {
      return lambdaName;
    }
    return `/aws/lambda/${lambdaName}-${this.env}`;
  }
}

/**
 * Time range utility class
 */
class TimeRangeUtil {
  static parseDate(dateString) {
    if (!dateString) return null;
    
    let date;
    
    // Check if it's already a full ISO string (contains 'T' or 'Z')
    if (dateString.includes('T') || dateString.includes('Z')) {
      date = new Date(dateString);
    } else {
      // Assume it's YYYY-MM-DD format and append time
      date = new Date(dateString + 'T00:00:00Z');
    }
    
    if (isNaN(date.getTime())) {
      throw new Error(`Invalid date format: ${dateString}. Expected YYYY-MM-DD or ISO string (e.g., 2025-08-05T10:30:00Z)`);
    }
    return Math.floor(date.getTime() / 1000); // Convert to seconds
  }

  static getDefaultStartTime() {
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    return Math.floor(oneDayAgo.getTime() / 1000);
  }

  static getDefaultEndTime() {
    return Math.floor(Date.now() / 1000);
  }

  static formatTimestamp(timestamp) {
    return new Date(timestamp * 1000).toISOString();
  }
}

/**
 * Query builder class for constructing CloudWatch Insights queries
 */
class QueryBuilder {
  constructor(config) {
    this.config = config;
  }

  buildFilterString(baseFilter, filters = {}) {
    let filterString = baseFilter || '';

    const { universityId, termId, userId } = filters;

    if (universityId) {
      const universityFilter = `@message like /universityId.*${universityId}[^0-9]/`;
      filterString = filterString ? `${filterString} and ${universityFilter}` : universityFilter;
    }

    if (termId) {
      const termFilter = `@message like /termId.*${termId}[^0-9]/`;
      filterString = filterString ? `${filterString} and ${termFilter}` : termFilter;
    }

    if (userId) {
      const userFilter = `@message like /userId.*${userId}[^0-9]/`;
      filterString = filterString ? `${filterString} and ${userFilter}` : userFilter;
    }

    return filterString;
  }

  buildQueryString(filterString, sortOrder = '@timestamp asc') {
    return `fields @timestamp, @message, @logStream, @log, @requestId | sort ${sortOrder} | filter ${filterString} | limit ${this.config.maxBatchSize}`;
  }
}

/**
 * AWS CloudWatch service class for executing queries
 */
class CloudWatchService {
  constructor() {
    this.config = new CloudWatchConfig();
  }

  async executeCommand(command, args) {
    return new Promise((resolve, reject) => {
      const child = spawn(command, args, { stdio: ['pipe', 'pipe', 'pipe'] });
      
      let stdout = '';
      let stderr = '';

      child.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      child.on('close', (code) => {
        if (code === 0) {
          resolve(stdout.trim());
        } else {
          reject(new Error(`Command failed with code ${code}: ${stderr}`));
        }
      });

      child.on('error', (error) => {
        reject(error);
      });
    });
  }

  async startQuery(logGroupName, startTime, endTime, queryString) {
    const args = [
      'logs', 'start-query',
      '--log-group-name', logGroupName,
      '--start-time', startTime.toString(),
      '--end-time', endTime.toString(),
      '--query-string', queryString,
      '--query', 'queryId',
      '--output', 'text'
    ];

    return await this.executeCommand('aws', args);
  }

  async getQueryStatus(queryId) {
    const args = [
      'logs', 'get-query-results',
      '--query-id', queryId,
      '--query', 'status',
      '--output', 'text'
    ];

    return await this.executeCommand('aws', args);
  }

  async getQueryResults(queryId) {
    const args = [
      'logs', 'get-query-results',
      '--query-id', queryId,
      '--output', 'json'
    ];

    const result = await this.executeCommand('aws', args);
    return JSON.parse(result);
  }

  async waitForQueryCompletion(queryId) {
    while (true) {
      const status = await this.getQueryStatus(queryId);
      
      if (['Complete', 'Failed', 'Cancelled', 'Timeout'].includes(status)) {
        return status;
      }

      console.error(`Query status: ${status}`);
      await new Promise(resolve => setTimeout(resolve, this.config.pollInterval));
    }
  }
}

/**
 * Query executor class for handling recursive queries
 */
class QueryExecutor {
  constructor(cloudWatchService, queryBuilder) {
    this.cloudWatchService = cloudWatchService;
    this.queryBuilder = queryBuilder;
    this.config = cloudWatchService.config;
    this.batchDir = null;
    this.batchCount = 0;
    this.totalResults = 0;
    this.allResults = []; // Collect all results for single JSON output
  }

  async initialize() {
    this.batchDir = await fs.mkdtemp(path.join(os.tmpdir(), 'cloudwatch-'));
    this.batchCount = 0;
    this.totalResults = 0;
    this.allResults = []; // Reset results collection
  }

  async cleanup() {
    if (this.batchDir) {
      console.error(`Batch files preserved in: ${this.batchDir}`);
    }
  }

  async runSingleQuery(startTime, endTime, queryString) {
    console.error(`Running query for time range: ${TimeRangeUtil.formatTimestamp(startTime)} to ${TimeRangeUtil.formatTimestamp(endTime)}`);
    
    const queryId = await this.cloudWatchService.startQuery(
      this.logGroupName,
      startTime,
      endTime,
      queryString
    );

    if (!queryId) {
      throw new Error('Failed to start query');
    }

    console.error(`Query ID: ${queryId}`);

    const status = await this.cloudWatchService.waitForQueryCompletion(queryId);
    
    if (status !== 'Complete') {
      throw new Error(`Query failed with status: ${status}`);
    }

    return await this.cloudWatchService.getQueryResults(queryId);
  }

  async saveBatchResults(results, outputFile, rawOutput) {
    this.batchCount++;
    const batchFile = path.join(this.batchDir, `batch_${this.batchCount}.json`);
    await fs.writeFile(batchFile, JSON.stringify(results, null, 2));

    const count = results.results ? results.results.length : 0;
    console.error(`Batch returned ${count} results`);

    // Collect results for single JSON output
    if (results.results) {
      this.allResults.push(...results.results);
    }

    // Output to stdout if no output file specified
    if (!outputFile) {
      if (rawOutput) {
        const messages = results.results
          ?.filter(r => r.some(field => field.field === '@message'))
          ?.map(r => r.find(field => field.field === '@message')?.value)
          ?.filter(Boolean) || [];
        messages.forEach(msg => console.log(msg));
      }
      // Note: JSON output is handled at the end when all batches are complete
    }

    this.totalResults += count;
    console.error(`Total results so far: ${this.totalResults}`);

    return count;
  }

  async queryAll(startTime, endTime, queryString, options = {}) {
    const { limit = this.config.defaultLimit, outputFile, rawOutput } = options;

    const results = await this.runSingleQuery(startTime, endTime, queryString);
    const count = await this.saveBatchResults(results, outputFile, rawOutput);

    // Check if we've reached the limit
    if (this.totalResults >= limit) {
      console.error(`Reached results limit (${limit})`);
      return;
    }

    // If we got max results, split the remaining window
    if (count >= this.config.maxBatchSize) {
      console.error('Batch hit 10,000 limit. Splitting remaining window...');
      
      const lastTimestamp = this.extractLastTimestamp(results);
      if (lastTimestamp) {
        const splitStart = lastTimestamp + 1; // Nudge by +1 second to avoid duplicates
        const mid = Math.floor((splitStart + endTime) / 2);

        if (splitStart < endTime) {
          await this.queryAll(splitStart, mid, queryString, options);
          await this.queryAll(mid, endTime, queryString, options);
        }
      } else {
        console.error('Warning: Could not extract last timestamp for splitting');
      }
    }
  }

  extractLastTimestamp(results) {
    if (!results.results || results.results.length === 0) return null;

    const timestamps = results.results
      .map(result => result.find(field => field.field === '@timestamp')?.value)
      .filter(Boolean)
      .sort();

    if (timestamps.length === 0) return null;

    const lastTimestampStr = timestamps[timestamps.length - 1];
    const date = new Date(lastTimestampStr);
    return Math.floor(date.getTime() / 1000);
  }

  async combineBatchFiles(outputFile) {
    if (!this.batchDir || this.batchCount === 0) return;

    console.error(`Combining ${this.batchCount} batch files into ${outputFile}...`);

    const combinedResults = { results: [] };

    for (let i = 1; i <= this.batchCount; i++) {
      const batchFile = path.join(this.batchDir, `batch_${i}.json`);
      try {
        const batchData = JSON.parse(await fs.readFile(batchFile, 'utf8'));
        if (batchData.results) {
          combinedResults.results.push(...batchData.results);
        }
      } catch (error) {
        console.error(`Error reading batch file ${batchFile}:`, error.message);
      }
    }

    await fs.writeFile(outputFile, JSON.stringify(combinedResults, null, 2));
    console.error('Combination completed successfully!');
  }

  outputFinalResults(rawOutput) {
    if (rawOutput) {
      // Raw output was already handled during batch processing
      return;
    }

    // Output single JSON object to stdout
    const output = { results: this.allResults };
    console.log(JSON.stringify(output, null, 2));
  }
}

/**
 * Command line argument parser
 */
class ArgumentParser {
  static parse(args) {
    const options = {
      lambdaName: null,
      filter: null,
      rawOutput: false,
      sortOrder: '@timestamp desc',
      startDate: null,
      endDate: null,
      universityId: null,
      termId: null,
      userId: null,
      limit: 100,
      outputFile: null
    };

    for (let i = 0; i < args.length; i++) {
      const arg = args[i];

      switch (arg) {
        case '-h':
        case '--help':
          this.showUsage();
          process.exit(0);
          break;
        case '--raw':
          options.rawOutput = true;
          break;
        case '--asc':
          options.sortOrder = '@timestamp asc';
          break;
        case '--start-date':
          options.startDate = args[++i];
          break;
        case '--end-date':
          options.endDate = args[++i];
          break;
        case '--university-id':
          options.universityId = args[++i];
          break;
        case '--term-id':
          options.termId = args[++i];
          break;
        case '--user-id':
          options.userId = args[++i];
          break;
        case '--limit':
          options.limit = parseInt(args[++i], 10);
          break;
        case '--output-file':
          options.outputFile = args[++i];
          break;
        default:
          if (!options.lambdaName) {
            options.lambdaName = arg;
          } else if (!options.filter) {
            options.filter = arg;
          }
          break;
      }
    }

    return options;
  }

  static showUsage() {
    console.log(`CloudWatch Insights Query Tool

Usage: ${process.argv[1]} [lambda-name (without env suffix)] [filter] [options]

Options:
  -h, --help           Show this help message
  --raw                Show only the message content
  --asc                Sort results in ascending order
  --start-date         Start date for the query (format: YYYY-MM-DD or ISO string, default: 24 hours ago)
  --end-date           End date for the query (format: YYYY-MM-DD or ISO string, default: now)
  --university-id      Filter by university ID
  --term-id            Filter by term ID
  --user-id            Filter by user ID
  --limit              Maximum total results to retrieve (default: 100)
  --output-file        Save results to file (JSON format)

Examples:                   # Last 24 hours, limit 100
  ${process.argv[1]} my-lambda '@message like /ERROR/'    # Last 24 hours, limit 100
  ${process.argv[1]} my-lambda '@message like /ERROR/' --raw
  ${process.argv[1]} my-lambda '@message like /ERROR/' --asc
  ${process.argv[1]} university-sync-partner-eligibility --university-id 190 --term-id 1730
  ${process.argv[1]} university-sync-partner-eligibility --user-id 6700214 --start-date 2025-08-05 --end-date 2025-08-06
  ${process.argv[1]} university-sync-partner-eligibility --university-id 190 --start-date 2025-08-05 --end-date 2025-08-06 --output-file results.json
  ${process.argv[1]} university-sync-partner-eligibility --university-id 190 --limit 50000 --start-date 2025-04-01 --end-date 2025-08-12 --output-file all-results.json
  ${process.argv[1]} my-lambda 'error' --start-date 2025-08-05T10:30:00Z --end-date 2025-08-05T15:45:00Z
  ${process.argv[1]} my-lambda 'error' --start-date 2025-08-05T10:30:00.000Z --end-date 2025-08-05T15:45:00.000Z

Safety Requirements:
  Default behavior: Query last 24 hours with limit of 100 results.
  Use --start-date/--end-date to override time range.
  Use --limit to override result limit.`);
  }
}

/**
 * Main application class
 */
class CloudWatchInsightsApp {
  constructor() {
    this.config = new CloudWatchConfig();
    this.cloudWatchService = new CloudWatchService();
    this.queryBuilder = new QueryBuilder(this.config);
    this.queryExecutor = new QueryExecutor(this.cloudWatchService, this.queryBuilder);
  }

  async run(options) {
    try {
      // Validate required parameters
      if (!options.lambdaName) {
        ArgumentParser.showUsage();
        process.exit(1);
      }

      // If no filter provided but we have specific filters, create a basic filter
      if (!options.filter && !options.universityId && !options.termId && !options.userId) {
        console.error('Error: Filter is required unless using --university-id, --term-id, or --user-id');
        ArgumentParser.showUsage();
        process.exit(1);
      }

      // Set up time range
      const startTime = options.startDate 
        ? TimeRangeUtil.parseDate(options.startDate)
        : TimeRangeUtil.getDefaultStartTime();
      
      const endTime = options.endDate
        ? TimeRangeUtil.parseDate(options.endDate)
        : TimeRangeUtil.getDefaultEndTime();

      // Build query
      const logGroupName = this.config.getLogGroupName(options.lambdaName);
      const filterString = this.queryBuilder.buildFilterString(options.filter, {
        universityId: options.universityId,
        termId: options.termId,
        userId: options.userId
      });
      const queryString = this.queryBuilder.buildQueryString(filterString, options.sortOrder);

      // Set up query executor
      this.queryExecutor.logGroupName = logGroupName;
      await this.queryExecutor.initialize();

      // Execute query
      console.error('Executing recursive CloudWatch Insights query...');
      console.error(`  Log Group: ${logGroupName}`);
      console.error(`  Time Range: ${TimeRangeUtil.formatTimestamp(startTime)} to ${TimeRangeUtil.formatTimestamp(endTime)}`);
      console.error(`  Filter: ${filterString}`);
      console.error(`  Limit: ${options.limit}`);

      await this.queryExecutor.queryAll(startTime, endTime, queryString, {
        limit: options.limit,
        outputFile: options.outputFile,
        rawOutput: options.rawOutput
      });

      // Combine results if output file specified
      if (options.outputFile) {
        await this.queryExecutor.combineBatchFiles(options.outputFile);
      }

      // Output final results to stdout if no output file specified
      if (!options.outputFile) {
        this.queryExecutor.outputFinalResults(options.rawOutput);
      }

      await this.queryExecutor.cleanup();

      console.error('');
      console.error('Query completed successfully!');
      console.error(`Total results: ${this.queryExecutor.totalResults}`);
      if (options.outputFile) {
        const stats = await fs.stat(options.outputFile);
        console.error(`Output file: ${options.outputFile}`);
        console.error(`File size: ${(stats.size / 1024).toFixed(2)} KB`);
      }

    } catch (error) {
      console.error('Error:', error.message);
      process.exit(1);
    }
  }
}

// Main execution
if (require.main === module) {
  const options = ArgumentParser.parse(process.argv.slice(2));
  const app = new CloudWatchInsightsApp();
  app.run(options);
}

module.exports = {
  CloudWatchConfig,
  TimeRangeUtil,
  QueryBuilder,
  CloudWatchService,
  QueryExecutor,
  ArgumentParser,
  CloudWatchInsightsApp
};
