module Builtins (defaultEnvironmentStack) where

import           Types

import           Control.Monad.Except


checkNumber :: Expr -> TransformerStack Double
checkNumber (StutterNumber a) = return a
checkNumber q                 = liftExcept $ throwError $ "not a number" ++ show q

checkFexpr :: Expr -> TransformerStack [Expr]
checkFexpr (StutterFexpr a) = return a
checkFexpr q                = liftExcept $ throwError $ "not a fexpr" ++ show q

checkSymbol :: Expr -> TransformerStack Symbol
checkSymbol (StutterSymbol a) = return a
checkSymbol q                 = liftExcept $ throwError $ "not a symbol" ++ show q

lengthCheck :: [Expr] -> Int -> TransformerStack ()
lengthCheck exprs expected = if expected ==  length exprs
    then return ()
    else liftExcept $ throwError $ "Incorrect amount of arguments, expected " ++ show expected

binOp :: [Expr] -> TransformerStack (Double, Double)
binOp exprs = do
    lengthCheck exprs 2
    a <- checkNumber (head exprs)
    b <- checkNumber (head (tail exprs))
    return (a, b)

addBuiltin :: Builtin
addBuiltin exprs = do
    (a, b) <- binOp exprs
    return $ StutterNumber (a + b)

subBuiltin :: Builtin
subBuiltin exprs = do
    (a, b) <- binOp exprs
    return $ StutterNumber (a - b)

mulBuiltin :: Builtin
mulBuiltin exprs = do
    (a, b) <- binOp exprs
    return $ StutterNumber (a * b)

divBuiltin :: Builtin
divBuiltin exprs = do
    (a, b) <- binOp exprs
    case b of
        0 -> liftExcept $ throwError "Can't divide by zero"
        _ -> return $ StutterNumber (a * b)

lambdaBuiltin :: Builtin
lambdaBuiltin exprs = do
    lengthCheck exprs 2
    args <- checkFexpr (head exprs)
    function <- checkFexpr (head (tail exprs))
    unpackedArgs <- mapM checkSymbol args
    return $ StutterFunction (unpackedArgs, function, emptyEnvironment)

defBuiltin :: Builtin
defBuiltin exprs = case exprs of
    (varlist:values@(_:_)) -> do
        vars <- checkFexpr varlist
        lengthCheck values (length vars)
        unpackedVars <- mapM checkSymbol vars
        mapM_ (uncurry addToEnvironment) (zip unpackedVars values)
        return $ StutterSexpr []
    _ -> liftExcept $ throwError "Need at least two arguments"

showBuiltin :: Builtin
showBuiltin exprs = do
    lengthCheck exprs 1
    liftIO $ print (head exprs)
    return $ StutterSexpr []

fexprOp :: [Expr] -> TransformerStack [Expr]
fexprOp exprs = do
    lengthCheck exprs 1
    checkFexpr (head exprs)

evalBuiltin :: Builtin
evalBuiltin exprs = StutterSexpr <$> fexprOp exprs

-- TODO: check list not empty, throw error
headBuiltin :: Builtin
headBuiltin exprs = head <$> fexprOp exprs

tailBuiltin :: Builtin
tailBuiltin exprs = StutterFexpr . tail <$> fexprOp exprs

initBuiltin :: Builtin
initBuiltin exprs = StutterFexpr . init <$> fexprOp exprs

lastBuiltin :: Builtin
lastBuiltin exprs = last <$> fexprOp exprs

-- TODO: cleanup
ifBuiltin :: Builtin
ifBuiltin [StutterNumber s, iftrue@(StutterFexpr _), iffalse@(StutterFexpr _)] = case s of
    0 -> evalBuiltin [iffalse]
    _ -> evalBuiltin [iftrue]
ifBuiltin _ = liftExcept $ throwError "if needs three arguments: number, fexpr, fexpr"

-- TODO: compare other types in prelude
compareBuiltin :: Builtin
compareBuiltin [StutterNumber a, StutterNumber b]
    | a < b     = return $ StutterNumber (-1)
    | a == b    = return $ StutterNumber 0
    | otherwise = return $ StutterNumber 1
compareBuiltin _ = liftExcept $ throwError "Can only compare numbers"

emptyBuiltin :: Builtin
emptyBuiltin [StutterFexpr []] = return $ StutterNumber 1
emptyBuiltin _ = return $ StutterNumber 0

defaultEnvironmentStack :: EnvStack
defaultEnvironmentStack =
    [createEnvironment builtins]
    where builtins = [
                        ("lifeTheUniverse", StutterNumber 42),
                        ("+", StutterBuiltin addBuiltin),
                        ("-", StutterBuiltin subBuiltin),
                        ("*", StutterBuiltin mulBuiltin),
                        ("/", StutterBuiltin divBuiltin),
                        ("\\", StutterBuiltin lambdaBuiltin),
                        ("def", StutterBuiltin defBuiltin),
                        ("show", StutterBuiltin showBuiltin),
                        ("eval", StutterBuiltin evalBuiltin),
                        ("head", StutterBuiltin headBuiltin),
                        ("tail", StutterBuiltin tailBuiltin),
                        ("init", StutterBuiltin initBuiltin),
                        ("last", StutterBuiltin lastBuiltin),
                        ("if", StutterBuiltin ifBuiltin),
                        ("cmp", StutterBuiltin compareBuiltin),
                        ("empty", StutterBuiltin emptyBuiltin)
                     ]
