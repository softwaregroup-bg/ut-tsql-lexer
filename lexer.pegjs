{
    function isKeyword(w) {
        return ['ADD','ALL','ALTER','AND','ANY','AS','ASC','AUTHORIZATION','BACKUP','BEGIN','BETWEEN','BREAK','BROWSE','BULK','BY','CASCADE','CASE','CHECK','CHECKPOINT','CLOSE','CLUSTERED','COALESCE','COLLATE','COLUMN','COMMIT','COMPUTE','CONSTRAINT','CONTAINS','CONTAINSTABLE','CONTINUE','CONVERT','CREATE','CROSS','CURRENT','CURRENT_DATE','CURRENT_TIME','CURRENT_TIMESTAMP','CURRENT_USER','CURSOR','DATABASE','DBCC','DEALLOCATE','DECLARE','DEFAULT','DELETE','DENY','DESC','DISK','DISTINCT','DISTRIBUTED','DOUBLE','DROP','DUMP','ELSE','END','ERRLVL','ESCAPE','EXCEPT','EXEC','EXECUTE','EXISTS','EXIT','EXTERNAL','FETCH','FILE','FILLFACTOR','FOR','FOREIGN','FREETEXT','FREETEXTTABLE','FROM','FULL','FUNCTION','GOTO','GRANT','GROUP','HAVING','HOLDLOCK','IDENTITY','IDENTITY_INSERT','IDENTITYCOL','IF','IN','INDEX','INNER','INSERT','INTERSECT','INTO','IS','JOIN','KEY','KILL','LEFT','LIKE','LINENO','LOAD','MERGE','NATIONAL','NOCHECK','NONCLUSTERED','NOT','NULL','NULLIF','OF','OFF','OFFSETS','ON','OPEN','OPENDATASOURCE','OPENQUERY','OPENROWSET','OPENXML','OPTION','OR','ORDER','OUTER','OUTPUT','OVER','PERCENT','PIVOT','PLAN','PRECISION','PRIMARY','PRINT','PROC','PROCEDURE','PUBLIC','RAISERROR','READ','READTEXT','RECONFIGURE','REFERENCES','REPLICATION','RESTORE','RESTRICT','RETURN','REVERT','REVOKE','RIGHT','ROLLBACK','ROWCOUNT','ROWGUIDCOL','RULE','SAVE','SCHEMA','SECURITYAUDIT','SELECT','SEMANTICKEYPHRASETABLE','SEMANTICSIMILARITYDETAILSTABLE','SEMANTICSIMILARITYTABLE','SESSION_USER','SET','SETUSER','SHUTDOWN','SOME','STATISTICS','SYSTEM_USER','TABLE','TABLESAMPLE','TEXTSIZE','THEN','TO','TOP','TRAN','TRANSACTION','TRIGGER','TRUNCATE','TRY_CONVERT','TSEQUAL','UNION','UNIQUE','UNPIVOT','UPDATE','UPDATETEXT','USE','USER','USING','VALUES','VARYING','VIEW','WAITFOR','WHEN','WHERE','WHILE','WITH','WITHIN GROUP','WRITETEXT'].includes(w.toUpperCase());
    }

    function report(t, code, message) {
        return {
            startLine: t.location.start.line,
            endLine: t.location.end.line,
            startColumn: t.location.start.column,
            endColumn: t.location.end.column,
            code: code,
            message: message,
            text: t.text
        }
    }

    var whitespaceSurround = ['%=' = '*=', '+=', '-=', '/=', '|=', '^=', '&=', '=', '<>', '!=', '>', '<', '+', '-', '*', '/', '&', '<=', '>=', '^', '|'];
    var whitespaceAfter = [',']
    var listIndent = [',', '(', 'AND', 'OR', 'BY'];

    function lintToken(tokens, line, index) {
        var t = tokens[line][index];
        var prev = (index > 0) && tokens[line][index - 1];
        var next = (index < tokens[line].length - 1) && tokens[line][index + 1];

        function isUnary() {
            var prev1 = (index > 1) && tokens[line][index - 2];
            return ['+', '-'].includes(t.text) &&
                next && ['literal', 'variable', 'word'].includes(next.type) &&
                (!prev || prev.text === '(' || (prev.text === ' ' && prev1 && prev1.type ==='operator'));
        }

        function isStar() {
            return (index > 0 && prev && next && t.text === '*' && prev.text === '(' && next.text === ')')
        }

        if (t.type === 'keyword' && t.text !== t.text.toUpperCase()) {
            return report(t, 'upppercase-keywords', 'Keywords must be in uppercase')
        } else if (t.type === 'literal' && t.text.toUpperCase() === 'NULL' && t.text !== t.text.toUpperCase()) {
            return report(t, 'upppercase-keywords', 'Keywords must be in uppercase')
        } else if (t.type === 'word' && t.text.charAt(0) === '"') {
            return report(t, 'no-doublequotes', 'Must use [...] instead of "..."')
        } else if (t.type === 'whitespace' && index === 0 && t.text.length % 4 !== 0) {
            return report(t, 'indent-size', 'Indentation must be multiple of 4')
        } else if (t.type === 'comment' && t.text !== t.text.trim()) {
            return report(t, 'no-trailing-whitespace', 'Trailing whitespace not allowed')
        } else if (t.type === 'whitespace' && index > 0 && t.text.length > 1) {
            return report(t, 'single-whitespace', 'Non indentation should be with single space')
        } else if (t.type !== 'newline' && index >= tokens[line].length-1) {
            return report(t, 'newline-required', 'Newline required at end of file')
        } else if (t.type === 'whitespace' && index >= tokens[line].length-2 && tokens[line][tokens[line].length-1].type === 'newline') {
            return report(t, 'no-trailing-whitespace', 'Trailing whitespace not allowed')
        } else if (isUnary() || isStar()) {
            return;
        } else if (t.type === 'operator' && whitespaceSurround.includes(t.text) && (index <= 0 || index >= tokens[line].length-1 || prev.type !== 'whitespace' || prev.text != ' ' || !['whitespace', 'newline'].includes(next.type) || (next.type === 'whitespace' && next.text != ' '))) {
            return report(t, 'whitespace-around', 'Operator should be surrounded with single space');
        } else if (t.type === 'operator' && whitespaceAfter.includes(t.text) && (index >= tokens[line].length-1 || !['whitespace', 'newline'].includes(next.type) || (next.type === 'whitespace' && next.text != ' '))) {
            return report(t, 'whitespace-after', 'Operator should be followed by single space');
        }
    }

    function stripNoopLines(lines) {
        return lines.filter(function(line){
            return line.find(function(token){
                return !['whitespace', 'newline', 'comment'].includes(token.type);
            })
        }).map(function(line){
            while (line.length && ['whitespace', 'newline', 'comment'].includes(line[line.length-1].type)) {
                line.pop();
            }
            return line;
        });
    }

    function lintLines(lines, linter) {
        return lines.reduce(function lintLine(prev, line, lineIndex){
            return prev.concat(line.reduce(function lint(p, token, tokenIndex){
                return p.concat(linter(lines, lineIndex, tokenIndex));
            },[])).filter(x=>x);
        }, []).filter(x=>x);
    }

    function lintIndent(tokens, line, index) {
        if (line === 0 || index > 0) return;
        var current = tokens[line][1];
        var prev = tokens[line - 1][1];
        var curIndent = tokens[line][0];
        var prevIndent = tokens[line - 1][0];
        var prevLastText = tokens[line - 1][tokens[line - 1].length-1].text;
        if (curIndent.type === 'whitespace') {
            curIndent = curIndent.text.length;
        } else {
            current = curIndent;
            curIndent = 0;
        }
        if (prevIndent.type === 'whitespace') {
            prevIndent = prevIndent.text.length;
        } else {
            prev = prevIndent;
            prevIndent = 0;
        }
        if (curIndent - prevIndent > 4) {
            return report(current, 'indent-step', 'Indentation step must not exceed 4')
        } else if (!['keyword', 'paren'].includes(current.type) && prev.type !== 'keyword' && curIndent !== prevIndent && !listIndent.includes(prevLastText)) {
            return report(current, 'indent-same', 'Lines starting with non-keyword must have same indentation')
        } else if (!['keyword', 'paren'].includes(current.type) && current.text !== ';' && prev.type === 'keyword' && curIndent <= prevIndent && !listIndent.includes(prevLastText)) {
            return report(current, 'indent-increase', 'Lines starting with non-keyword after lines starting with keyword must increas indentation')
        } else if (prev.type === 'keyword' && prev.text.toUpperCase() === 'BEGIN' && current.text.toUpperCase() !== 'END' && 4 !== curIndent - prevIndent) {
            return report(current, 'indent-after-begin', 'Line after BEGIN must increase indentation with 4')
        }
    }

    function lint(lines) {
        return lintLines(lines, lintToken).concat(lintLines(stripNoopLines(lines), lintIndent))
    }
}

body = token:wstoken* last:lintws {
    token.push(last);
    var result = token.reduce(function(prev, pair){
        pair.forEach && pair.forEach(function(cur){
            (cur.text != '') && prev[prev.length-1].push(cur);
            cur.type === 'newline' && prev.push([]);
        });
        return prev;
    },[[]]);
    !result[result.length-1].length && result.pop();
    return {
        lint: lint(result),
        tokens: result
    }
}

wstoken = ws:lintws token:token {return ws.concat(token)}
lintws = (WhiteSpace {return {type: 'whitespace', text: text(), location: location()}}
    / LineTerminatorSequence {return {type: 'newline', text: text(), location: location()}}
    / Comment {return {type: 'comment', text: text(), location: location()}})*
token = literal {return {type: 'literal', text: text(), location: location()}}
    / s:system_var {return {type: 'system', text:s, location: location()}}
    / t:globaltemp {return {type: 'globaltemp', text:t, location: location()}}
    / t:temp {return {type: 'temp', text:t, location: location()}}
    / v:variable {return {type: 'variable', text:v, location: location()}}
    / n:name {return isKeyword(n) ? {type: 'keyword', text:n, location: location()} : {type: 'word', text:n, location: location()}}
    / p:lparen {return {type: 'paren', text:p, location: location()}}
    / p:rparen {return {type: 'paren', text:p, location: location()}}
    / o: operator {return {type: 'operator', text:o, location: location()}}
lparen = "("
rparen = ")"
plus = "+"
minus = "-"
comma = ","
equals = "="
not_equals = "!=" / "<>"
ampersand = "&"
lt = "<"
lte = "<="
gt = ">"
gte = ">="
dotasterisk = ".*"
asterisk = "*"
percent = "%"
slash = "/"
semicolon = ";"
caret = "^"
mutate = "%=" / "*=" / "+=" / "-=" / "/=" / "|=" / "^=" / "&="
pipe = "|"
operator "operator" = mutate / caret / plus / minus / comma / equals / dotasterisk / decimal_point / slash / ampersand / not_equals / lte / gte / lt / gt / asterisk / percent / pipe / semicolon
name "word" =  "[" str:$[^\]]+ "]" {return text()} / '"' $[^"]+ '"' {return text()} / $[A-Za-z0-9_$]+
system_var "system variable" = "@@" name {return text()}
variable "variable" = "@" n:name {return text()}
globaltemp "global temporary table" = "##" name {return text()}
temp "temporary table" = "#" name {return text()}
literal = numeric_literal / string_literal / "NULL"i
string_literal "string" = "N"? quote s:([^'] / qq)* quote {return s.join('')}
qq = quote quote {return '\''}
numeric_literal "number" = digits:( ( ( ( digit )+ ( decimal_point ( digit )+ )? )
     / ( decimal_point ( digit )+ ) )
       ( E ( plus / minus )? ( digit )+ )? )
digit = [0-9]
quote = "'"
decimal_point = "."
E = "E"i
Zs = [\u0020\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000]
SourceCharacter = .
WhiteSpace "whitespace"
  = ("\t"
  / "\v"
  / "\f"
  / " "
  / "\u00A0"
  / "\uFEFF"
  / Zs)+
LineTerminator = [\n\r\u2028\u2029]
LineTerminatorSequence "end of line"  = "\r\n" / "\n" / "\r" / "\u2028" / "\u2029"
Comment "comment"  = MultiLineComment / SingleLineComment
MultiLineCommentBody = (!"*/" SourceCharacter)*{return {multi:text()}}
MultiLineComment = "/*" x:MultiLineCommentBody "*/" {return x}
SingleLineCommentBody = (!LineTerminator SourceCharacter)* {return {single:text()}}
SingleLineComment = "--" x:SingleLineCommentBody {return x}
