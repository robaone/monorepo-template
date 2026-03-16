const { ReleaseNotesGenerator, CategorizationProvider, SimpleLogicClient, GeminiClient } = require('../generate_release_notes');
const { execSync } = require('child_process');

function runCmd(cmd) {
    return execSync(cmd, { encoding: 'utf8' });
}
const fs = require('fs');
const path = require('path');

describe('generateReleaseNotes', () => {
    let jira_ticket_data;
    let generator;
    let issueProvider;
    let categorizationProvider;
    let isFeature = jest.fn();
    let isImprovement = jest.fn();
    let llmClient;
    beforeAll(() => {
        const template = fs.readFileSync(path.resolve(__dirname, '../templates/release_notes_template.html'), 'utf8');
        issueProvider = {
            getIssue: jest.fn(),
        };
        llmClient = {
            sendRequest: jest.fn()
        };
        categorizationProvider = {
            isFeature: isFeature,
            isImprovement: isImprovement
        };
        generator = new ReleaseNotesGenerator(issueProvider, template, categorizationProvider);
    });
    describe('ReleaseNotesGenerator', () => {
        it('should process full release', async () => {
            jira_ticket_data = require('./data/jira_ticket_data.json');
            const result = await generator.generateReleaseNotes(jira_ticket_data);
            expect(result).not.toBe(null);
        });
        it('should get parent impact summary', async () => {
            const issue = {
                fields: {
                    parent: {
                        key: 'parent'
                    },
                    customfield_11625: null
                }
            };
            const parent_issue = {
                key: 'parent',
                fields: {
                    customfield_11625: 'parent impact'
                }
            };
            issueProvider.getIssue.mockReturnValueOnce(parent_issue);
            const result = generator.extractImpactSummary(issue);
            expect(result).toBe('parent impact');
        });
        it('should create the release data', async () => {
            isFeature.mockReturnValueOnce(true).mockReturnValue(false);
            isImprovement.mockReturnValueOnce(true).mockReturnValue(true);
            const jira_ticket_data = {
                issues: [
                    {
                        key: 'TEST-123',
                        fields: {
                            issuetype: {
                                name: 'Task'
                            },
                            summary: 'summary',
                            customfield_11625: 'impact',
                            customfield_11628: 'additional resources',
                            customfield_11627: []
                        }
                    },
                    {
                        key: 'TEST-456',
                        fields: {
                            issuetype: {
                                name: 'Bug'
                            },
                            summary: 'summary',
                            customfield_11625: 'impact',
                            customfield_11628: 'additional resources',
                            customfield_11627: []
                        }
                    },
                    {
                        key: 'TEST-789',
                        fields: {
                            issuetype: {
                                name: 'Story'
                            },
                            summary: 'summary',
                            customfield_11625: 'impact',
                            customfield_11628: 'additional resources',
                            customfield_11627: []
                        }
                    }
                ]
            };
            const result = await generator.calculateReleaseData(jira_ticket_data.issues);
            expect(result.bugs.length).toBe(1);
            expect(result.improvements.length).toBe(2);
        });
        it('should populate the template', async () => {
            const data = {
                features: [],
                bugs: [
                    {
                        ticket_id: 'TEST-456',
                        summary: 'summary',
                        impact_summary: 'impact',
                        additional_resources: 'additional resources',
                        stakeholder_highlight: false
                    }
                ],
                improvements: [
                    {
                        ticket_id: 'TEST-123',
                        summary: 'summary',
                        impact_summary: null,
                        additional_resources: 'additional resources',
                        stakeholder_highlight: true
                    },
                    {
                        ticket_id: 'TEST-789',
                        summary: 'summary',
                        impact_summary: 'impact',
                        additional_resources: 'additional resources',
                        stakeholder_highlight: false
                    }
                ]
            };
            const result = generator.fromTemplate(data);
            console.log(result);
            expect(result).not.toBe(null);
            expect(result.includes('TEST-123')).toBe(true);
            expect(result.includes('TEST-456')).toBe(true);
            expect(result.includes('TEST-789')).toBe(true);
            // does not contain 'null'
            expect(result.includes('null')).toBe(false);
        });
    });
    describe('CategorizationProvider', () => {
        beforeAll(() => {
            categorizationProvider = new CategorizationProvider(jira_ticket_data.issues,llmClient);
        });
        it('should categorize as improvement', async () => {
            llmClient.sendRequest.mockResolvedValue({ categories: [
                {
                    ticket_id: 'PROJ-1906',
                    category: 'Improvement'
                },
                {
                    ticket_id: 'PROJ-1856',
                    category: 'Improvement'
                }
            ]});
            await categorizationProvider.categorizeTickets();
            const result1 = categorizationProvider.isImprovement('PROJ-1906', 'Epic');
            const result2 = categorizationProvider.isImprovement('PROJ-1856', 'Story');
            expect(result1).toBe(true);
            expect(result2).toBe(true);
        });
    });
    describe('SimpeLogicClient', () => {
        let client;
        beforeEach(() => {
            client = new SimpleLogicClient();
        });
        it('should categorize as feature and improvement', async () => {
            const data = [
                { key: 'PROJ-1906', summary: 'performance improvement', type: 'Epic' },
                { key: 'PROJ-1856', summary: 'create a class', type: 'Story' },
            ];
            const result = await client.sendRequest(data);
            expect(result.categories.length).toBe(2);
            expect(result.categories[0].category).toBe('Improvement');
            expect(result.categories[1].category).toBe('Improvement');
        });
    });
    describe('GeminiClient', () => {
        let client;
        let fetchMock = jest.fn();
        beforeEach(() => {
            client = new GeminiClient(process.env.GEMINI_API_KEY, fetchMock);
        });
        it('should categorize as feature and improvement', async () => {
            const expectedCategories = { categories: [{ ticket_id: 'PROJ-1906', category: 'Improvement' }, { ticket_id: 'PROJ-1856', category: 'Feature' }] };
            const expectedResponse = { candidates: [{ content: { parts: [{ text: JSON.stringify(expectedCategories) }] }}] };
            fetchMock.mockResolvedValue(expectedResponse);
            const data = [
                { key: 'PROJ-1906', summary: 'performance improvement', type: 'Epic' },
                { key: 'PROJ-1856', summary: 'create a class', type: 'Story' },
            ];
            const result = await client.sendRequest(data);
            expect(result.categories.length).toBe(2);
            expect(result.categories[0].category).toBe('Improvement');
            expect(result.categories[1].category).toBe('Feature');
        });
    });
    describe('runCmd', () => {
        it('should run a command', () => {
            const cmd = 'echo "hello world"';
            const result = runCmd(cmd);
            expect(result).toBe('hello world\n');
        });
    });
});
