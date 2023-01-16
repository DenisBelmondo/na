--
-- lexer will get 10000000000 refactors
--

require 'string'
require 'table'

local src = [[
fn int main(array<string> args) {
    for i in #args {
    }
}
]]

local function new_token()
    return setmetatable({text = ''}, {
        __tostring = function (self)
            return '<' .. (self.type or 'unknown') .. '>: ' .. self.text
        end;

        __concat = function (left, right)
            return tostring(left) .. tostring(right)
        end;
    })
end

local function lex(p_src)
    local tokens = {}
    local token = nil

    local i = 1
    local line = 1

    while true do
        if i >= #p_src then
            if token then
                table.insert(tokens, token)
                token = nil
            end

            return tokens
        end

        local c = p_src:sub(i, i)

        --
        -- capturing function
        --

        local function peek()
            local ii = i + 1
            if ii <= #p_src then
                return p_src:sub(ii, ii)
            end
        end

        local function advance(dont_consume)
            if token and not dont_consume then
                token.text = token.text .. c
            end

            i = i + 1
            c = p_src:sub(i, i)
        end

        local function push()
            if token then
                table.insert(tokens, token)
                token = nil
            end
        end

        --
        -- first off, skip whitespace
        --

        while c:find('%s') do
            if c == '\n' then
                line = line + 1
            end

            push()
            advance(true)
        end

        --
        -- (lazily) initialize token
        --

        if not token then
            token = new_token()
        end

        if c == '"' then
            advance(true)
            while c ~= '"' do
                advance()
            end
            token.type = 'literal.string'
            push()
            advance(true)
        end

        if not token then
            token = new_token()
        end

        if c == "'" then
            advance(true)
            while c ~= "'" do
                advance()
            end
            token.type = 'literal.string'
            push()
            advance(true)
        end

        if not token then
            token = new_token()
        end

        local punctuation = {
            [';'] = 'punctuation.semicolon',
            ['{'] = 'punctuation.block.start',
            ['}'] = 'punctuation.block.end',
            [','] = 'punctuation.comma',
            ['('] = 'punctuation.paren.open',
            [')'] = 'punctuation.paren.close',
            ['.'] = 'punctuation.accessor',
            ['['] = 'punctuation.square-bracket.open',
            [']'] = 'punctuation.square-bracket.close',
            ['#'] = 'operator.sizeof',
        }

        local operators = {
            ['+'] = 'arithmetic.add',
            ['-'] = 'arithmetic.sub',
            ['*'] = 'arithmetic.mul',
            ['/'] = 'arithmetic.div',
            ['%'] = 'arithmetic.mod',
            ['&'] = 'bitwise.and',
            ['|'] = 'bitwise.or',
            ['^'] = 'bitwise.xor',
            ['~'] = 'bitwise.not',
        }

        -- punctuation
        if punctuation[c] then
            token.type = punctuation[c]
            advance()
            push()

        -- assignment operator is a special boy
        elseif c == '=' then
            if peek() == '=' then
                token.type = 'operator.comparison'
                advance()
                advance()
                push()
            else
                token.type = 'operator.assignment'
                advance()
                push()
            end

        elseif c == '<' then
            if peek() == '<' then
                token.type = 'operator.bitwise.shl'
                advance()
                if peek() == '=' then
                    token.type = 'operator.compound.bitwise.shl'
                    advance()
                end
                advance()
                push()
            elseif peek() == '=' then
                token.type = 'operator.comparison.leq'
                advance()
                advance()
                push()
            else
                token.type = 'punctuation.angle-bracket.open'
                advance()
                push()
            end

        elseif c == '>' then
            if peek() == '>' then
                token.type = 'operator.bitwise.shr'
                advance()
                if peek() == '=' then
                    token.type = 'operator.compound.bitwise.shr'
                    advance()
                end
                advance()
                push()
            elseif peek() == '=' then
                token.type = 'operator.comparison.geq'
                advance()
                advance()
                push()
            else
                token.type = 'punctuation.angle-bracket.close'
                advance()
                push()
            end

        -- same with operators
        elseif operators[c] then
            if peek() == '=' then
                token.type = 'operator.compound.' .. operators[c]
                advance()
            else
                token.type = 'operator.' .. operators[c]
            end

            advance()
            push()

        -- numeric literals
        elseif c:find('%d') then
            token.type = 'literal.numeric'

            while (c:find('[\\.%dFLUflu]')) do
                advance()
            end

            push()
        -- identifiers and keywords
        elseif c:find('[_%a]') then
            token.type = 'identifier'

            while (c:find('[_%w]')) do
                advance()
            end

            token.type = ({
                ['namespace'] = 'keyword.namespace',
                ['struct']    = 'keyword.struct',
                ['fn']        = 'keyword.fn',
                ['return']    = 'keyword.return',
                ['for']       = 'keyword.for',
                ['in']        = 'keyword.in'})[token.text]
            or token.type

            push()

        -- misc
        elseif not c:find('%s') then
            while not c:find('%s') do
                advance()
            end

            print(tostring(line) .. ':' .. (i % line) .. ': error: ' .. 'unrecognized token `' .. token.text .. "'")
            return {}
        end
    end

    --- @diagnostic disable-next-line: unreachable-code
    return tokens
end

for _, value in pairs(lex(src)) do
    print(value)
end
