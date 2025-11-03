# Contributing to OSCAR

Thank you for your interest in contributing to OSCAR! We welcome contributions from the community.

## How to Contribute

### Adding New KQL Queries

1. **Fork the repository**
   ```bash
   git clone https://github.com/bobsyourmom/OSCAR.git
   cd OSCAR
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/new-compliance-query
   ```

3. **Add your query to the agent manifest**

   Edit `CONTEXT/agent-manifest-rebuild.yaml` and add your skill:

   ```yaml
   - Name: YourQueryName
     DisplayName: Your Query Display Name
     Description: What your query does
     Inputs: []
     Settings:
       Target: LogAnalytics
       Template: |-
         let findings = YourTable
         | where TimeGenerated > ago(24h)
         | project TimeGenerated, Field1, Field2;

         let hasResults = toscalar(findings | count) > 0;

         union findings,
         (print placeholder = 1
         | where not(hasResults)
         | extend
             FindingType = "No Findings",
             Status = "Completed",
             ReportName = "YourQueryName"
         | project-away placeholder)
   ```

4. **Test your query**

   Use the test Logic App to validate without consuming SCUs:
   ```bash
   cd test
   az deployment group create \
     --resource-group sentinel \
     --template-file logicapp-test-single.json \
     --mode Incremental
   ```

5. **Document your changes**

   Update the README.md to include your new query in the list.

6. **Commit and push**
   ```bash
   git add .
   git commit -m "Add compliance query for [framework/requirement]"
   git push origin feature/new-compliance-query
   ```

7. **Open a Pull Request**

### Query Requirements

- **Always include audit trail pattern** - Return "No Findings" when no results
- **Map to compliance frameworks** - Include ControlID, Framework fields
- **Use standard field names** - Follow schema in TOOLS_AND_COMPONENTS.md
- **Include MITRE ATT&CK mapping** - When applicable (Technique, Tactics)
- **Test with real data** - Validate against actual Sentinel workspace

### Code Style

- Use consistent indentation (2 spaces for YAML, 4 for Python)
- Comment complex KQL logic
- Follow naming conventions: PascalCase for skill names

### Pull Request Process

1. Ensure all tests pass
2. Update documentation
3. Add your query to the README.md list
4. Request review from maintainers
5. Address any feedback

## Reporting Issues

- Use GitHub Issues
- Include Logic App run history (sanitized)
- Provide KQL query if relevant
- Include error messages and screenshots

## Questions?

- Open a GitHub Discussion
- Tag issues with `question` label

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

Thank you for contributing to OSCAR! 🕶️
