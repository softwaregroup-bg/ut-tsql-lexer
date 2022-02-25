# Transact SQL lexer and linter

## API

```javascript
try {
    let parsed = require('ut-tsql-lexer').parse('select * FROM someTable');
    parsed.lint.forEach(({
        startLine,
        startColumn,
        endLine,
        endColumn,
        code,
        message,
        text
    }) => {
        // process lint warnings
    });

    parsed.tokens.forEach(line => {
        line.forEach(({
            type, // whitespace, newline, comment, literal, system, globaltemp,
                  // temp, variable, keyword, word, paren, operator
            text,
            location
        }) => {
            // process tokens of each line of source code
        });
    });
} catch ({message, location}) {
    // process parse errors
}
```

## Lint rules

- `upppercase-keywords`: Keywords must be in uppercase
- `no-doublequotes`: Must use [...] instead of "..."
- `indent-size`: Indentation must be multiple of 4
- `no-trailing-whitespace`: Trailing whitespace not allowed
- `single-whitespace`: Non indentation should be with single space
- `newline-required`: Newline required at end of file
- `whitespace-around`: Operator should be surrounded with single space
- `whitespace-after`: Operator should be followed by single space
- `indent-step`: Indentation step must not exceed 4
- `indent-same`: Lines starting with non-keyword must have same indentation
- `indent-increase`: Lines starting with non-keyword after lines starting with
  keyword must increase indentation
- `indent-after-begin`: Line after BEGIN must increase indentation with 4
