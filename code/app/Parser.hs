module Parser(
  module Parser
) where

import Text.Parsec
import Text.Parsec.String
import Text.Parsec.Expr
import System.IO
import Debug.Trace

data Contract = Contract String [StateVariable] [Function]
  deriving (Show)

data DataType = IntType | FloatType | BoolType | AddressType | ListType [DataType] | MapType (DataType, DataType) | StateType
  deriving (Show)

data StateVariable = MapDecl String DataType | ListDecl String DataType | IntDecl String DataType | FloatDecl String DataType | BoolDecl String DataType | AddressDecl String DataType
  deriving (Show)
  
data Function = Function String [DataType] DataType Expr
  deriving (Show)

data Expr = Literal Literal | Var String | FunctionCall String [Expr] | FunctionExpr String [Expr] Expr | IfExpr Expr Expr Expr | MapExpr String Expr | MapAssignExpr String Expr Expr | ListExpr String Expr | ListAssignExpr String Expr Expr | BinaryExpr BinaryOperator Expr Expr | UnaryExpr UnaryOperator Expr | CompareExpr CompareOperator Expr Expr
  deriving (Show)

data Literal = IntLit Integer | FloatLit Float | BoolLit Bool | AddressLit String
  deriving (Show)

data BinaryOperator = Plus | Minus | Times | Divide | And | Or | In
  deriving (Show)

data UnaryOperator = Not
  deriving (Show)

data CompareOperator = Less | Greater | LessEq | GreaterEq | Equal | NotEqual
  deriving (Show)


identifier :: Parser String
identifier = trace "identifier" $ do
    firstChar <- letter
    rest <- many (letter <|> digit <|> char '.')
    return (firstChar:rest)

literalParser :: Parser Expr
literalParser = do
  try floatLiteralParser
    <|> try intLiteralParser
    <|> try boolLiteralParser
    <|> try addressLiteralParser

intLiteralParser :: Parser Expr
intLiteralParser = do
  n <- many1 digit
  return (Literal (IntLit (read n)))

boolLiteralParser :: Parser Expr
boolLiteralParser = do
  try (string "true" >> return (Literal (BoolLit True)))
    <|> (string "false" >> return (Literal (BoolLit False)))

addressLiteralParser :: Parser Expr
addressLiteralParser = do
  string "0x"
  address <- count 40 (satisfy isHexDigit)
  return (Literal (AddressLit address))

floatLiteralParser :: Parser Expr
floatLiteralParser = do
  n <- many1 digit
  char '.'
  d <- many1 digit
  return (Literal (FloatLit (read (n ++ "." ++ d))))

isHexDigit :: Char -> Bool
isHexDigit c = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')

stateVariableParser :: Parser StateVariable
stateVariableParser = try mapDeclParser
            <|> try listDeclParser
            <|> try addressDeclParser
            <|> try floatDeclParser
            <|> try intDeclParser
            <|> try boolDeclParser

intDeclParser :: Parser StateVariable
intDeclParser = do
  name <- identifier
  spaces
  char ':'
  spaces
  ty <- intTypeParser
  return (IntDecl name ty)

floatDeclParser :: Parser StateVariable
floatDeclParser = do
  name <- identifier
  spaces
  char ':'
  spaces
  ty <- floatTypeParser
  return (FloatDecl name ty)

boolDeclParser :: Parser StateVariable
boolDeclParser = do
  name <- identifier
  spaces
  char ':'
  spaces
  ty <- boolTypeParser
  return (BoolDecl name ty)

addressDeclParser :: Parser StateVariable
addressDeclParser = do
  name <- identifier
  spaces
  char ':'
  spaces
  ty <- addressTypeParser
  return (AddressDecl name ty)

mapDeclParser :: Parser StateVariable
mapDeclParser = do
  name <- identifier
  spaces
  char ':'
  spaces
  ty <- mapTypeParser
  return (MapDecl name ty)

listDeclParser :: Parser StateVariable
listDeclParser = do
  name <- identifier
  spaces
  char ':'
  spaces
  ty <- listTypeParser
  return (ListDecl name ty)

--type parsers--
dataTypeParser :: Parser DataType
dataTypeParser = try stateTypeParser
                <|> try mapTypeParser
                <|> try listTypeParser
                <|> try addressTypeParser
                <|> try floatTypeParser
                <|> try intTypeParser
                <|> try boolTypeParser

floatTypeParser :: Parser DataType
floatTypeParser = do
  string "float"
  return FloatType

intTypeParser :: Parser DataType
intTypeParser = do
  string "int"
  return IntType


boolTypeParser :: Parser DataType
boolTypeParser = do
  string "bool"
  return BoolType

addressTypeParser :: Parser DataType
addressTypeParser = do
  string "address"
  return AddressType

listTypeParser :: Parser DataType
listTypeParser = do
  char '['
  ty <- dataTypeParser
  char ']'
  return (ListType [ty])

mapTypeParser :: Parser DataType
mapTypeParser = do
    string "mapping"
    char '('
    ty1 <- dataTypeParser
    string "->"
    ty2 <- dataTypeParser
    char ')'
    return (MapType (ty1, ty2))

stateTypeParser :: Parser DataType
stateTypeParser = do
    string "state"
    return StateType


--expression parsers--

varExprParser :: Parser Expr
varExprParser = trace "Variable" $ do
  varName <- identifier
  return (Var varName)

--works
listExprParser :: Parser Expr
listExprParser = do
  name <- identifier
  char '['
  index <- intLiteralParser
  char ']'
  return (ListExpr name index)

listAssignParser :: Parser Expr
listAssignParser = do
  name <- identifier
  char '['
  index <- intLiteralParser
  char ']'
  spaces
  char '='
  spaces
  val <- literalParser
  return (ListAssignExpr name index val)

--works
mapExprParser :: Parser Expr
mapExprParser = trace "Hello" $ do
  name <- identifier
  char '{'
  key <- exprParser
  char '}'
  trace "Map" $ return (MapExpr name key)

mapAssignParser :: Parser Expr
mapAssignParser = do
  name <- identifier
  char '{'
  key <- exprParser
  char '}'
  spaces
  char '='
  spaces 
  val <- exprParser
  return (MapAssignExpr name key val)

--works
exprParser :: Parser Expr
exprParser = try functionExprParser
           <|> try functionCallParser
           <|> try ifExprParser
           <|> try mapAssignParser
           <|> try listAssignParser
           <|> try listExprParser
           <|> try mapExprParser
           <|> try binaryExprParser
           <|> try compareExprParser
           <|> try unaryExprParser
           <|> try varExprParser
           <|> try literalParser


--works
ifExprParser :: Parser Expr
ifExprParser = do
  trace "if" $ string "if"
  spaces
  condition <- try binaryExprParser <|> try literalParser <|> try unaryExprParser
  newline
  trace "then" $ string "then"
  spaces
  thenExpr <- try binaryExprParser <|> try literalParser <|> try unaryExprParser
  newline
  string "else"
  spaces
  elseExpr <- try binaryExprParser <|> try literalParser <|> try unaryExprParser
  return (IfExpr condition thenExpr elseExpr)

--works
binaryExprParser :: Parser Expr
binaryExprParser = do
    term <- try intLiteralParser <|> try floatLiteralParser <|> try varExprParser
    spaces
    rest <- many (do { op <- binaryOperatorParser; spaces; term <- try intLiteralParser <|> try floatLiteralParser <|> try varExprParser; spaces; return (op, term) } )
    return $ foldl (\acc (op, term) -> BinaryExpr op acc term) term rest

--works
unaryExprParser :: Parser Expr
unaryExprParser = do
  op <- unaryOperatorParser
  e <- exprParser
  return $ UnaryExpr op e

compareExprParser :: Parser Expr
compareExprParser = do
    term <- try intLiteralParser <|> try floatLiteralParser <|> varExprParser
    spaces
    rest <- many (do { op <- compareOperatorParser; spaces; term <- try intLiteralParser <|> try floatLiteralParser <|> varExprParser; spaces; return (op, term) } )
    return $ foldl (\acc (op, term) -> CompareExpr op acc term) term rest





--function parsers
--works
functionCallParser :: Parser Expr
functionCallParser = do
  functionName <- identifier
  char '('
  args <- sepBy exprParser (char ',')
  char ')'
  return (FunctionCall functionName args)

-- tested and works!
functionExprParser :: Parser Expr
functionExprParser = trace "start" $ do
  var <- identifier
  spaces
  args <- sepEndBy (try varExprParser <|> try literalParser <|> try listExprParser <|> try mapExprParser) spaces
  string "="
  spaces
  expr <- exprParser
  trace "got" $ return (FunctionExpr var args expr)

--works
functionSigParser :: Parser (String, [DataType], DataType)
functionSigParser = do
    funcName <- identifier
    spaces
    char ':'
    spaces
    args <- between (char '(') (char ')') (sepBy dataTypeParser (string " -> "))
    string " -> "
    returnType <- dataTypeParser
    return (funcName, args, returnType)

-- works
functionParser :: Parser Function
functionParser = do
    (name, inputTypes, outputType) <- functionSigParser
    newline
    expr <- functionExprParser
    skipMany (oneOf " \t\r\n")
    return (Function name inputTypes outputType expr)





--operator parsers
binaryOperatorParser :: Parser BinaryOperator
binaryOperatorParser =
  try (string "+" >> return Plus)
  <|> try (string "-" >> return Minus)
  <|> try (string "*" >> return Times)
  <|> try (string "/" >> return Divide)
  <|> try (string "and" >> return And)
  <|> try (string "or" >> return Or)
  <|> try (string "in" >> return In)

unaryOperatorParser :: Parser UnaryOperator
unaryOperatorParser =
  try (string "!" >> return Not)

compareOperatorParser :: Parser CompareOperator
compareOperatorParser = do
    try (string "<" >> return Less)
    <|> try (string ">" >> return Greater)
    <|> try (string "==" >> return Equal)
    <|> try (string "<=" >> return LessEq)
    <|> try (string ">=" >> return GreaterEq)
    <|> try (string "!=" >> return NotEqual)



contractParser :: Parser Contract
contractParser = trace "Contract" $ do
  string "contract"
  spaces
  contractName <- identifier
  spaces
  char '{'
  newline
  stateVars <- stateParser
  skipMany (oneOf " \n\t\r")
  functions <- manyTill functionParser (string "}")
  return (Contract contractName stateVars functions)

--works
stateParser :: Parser [StateVariable]
stateParser = trace "State" $ do
  string "state"
  spaces
  char '{'
  newline
  stateVars <- sepEndBy stateVariableParser (newline)
  trace "Success" $ skipMany (oneOf " \n\t\r")
  char '}'
  trace "State Parsed" $ return stateVars

--works




--main :: IO ()
--main = do
--    contents <- readFile "example.fafel"
--    case parse contractParser "example.fafel" contents of
--        Left error -> print error
--        Right ast -> print ast