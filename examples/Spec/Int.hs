{-# LANGUAGE TypeFamilies #-}

module Spec.Int (HasLogicalModel (..), IntProp(..),intGenTests,intPureTests,intPlutarchTests) where
import Proper.HasLogicalModel
import Proper.LogicalModel
import Proper.HasParameterisedGenerator
import Proper.HasPlutusTestRunner
import Proper.HasPureTestRunner
import SAT.MiniSat ( Formula (..) )
import Hedgehog (forAll)
import qualified Hedgehog.Gen as Gen
import Hedgehog.Range (linear)
import Data.Proxy (Proxy(..))
import Test.Tasty (TestTree,testGroup)
import Test.Tasty.Hedgehog (fromGroup)

import Plutarch (compile)
import Plutarch.Prelude

data IntProp =
      IsNegative
    | IsPositive
    | IsZero
    | IsLarge
    | IsSmall
    | IsMaxBound
    | IsMinBound
    deriving stock (Eq,Ord,Enum,Show,Bounded)

instance LogicalModel IntProp where
  logic = ExactlyOne [Var IsNegative, Var IsPositive, Var IsZero]
     :&&: ExactlyOne [Var IsLarge, Var IsSmall]
     :&&: (Var IsZero :->: Var IsSmall)
     :&&: (Var IsMaxBound :->: (Var IsLarge :&&: Var IsPositive))
     :&&: (Var IsMinBound :->: (Var IsLarge :&&: Var IsNegative))

instance HasLogicalModel IntProp Int where
  satisfiesProperty IsNegative i = i < 0
  satisfiesProperty IsPositive i = i > 0
  satisfiesProperty IsMaxBound i = i == maxBound
  satisfiesProperty IsMinBound i = i == minBound
  satisfiesProperty IsZero     i = i == 0
  satisfiesProperty IsLarge    i = i > 10 || i < -10
  satisfiesProperty IsSmall    i = i <= 10 && i >= -10

instance HasParameterisedGenerator IntProp Int where
  parameterisedGenerator s = forAll $ do
    i <- if IsZero `elem` s
           then pure 0
           else if IsSmall `elem` s
                  then Gen.int (linear 1 10)
                  else if IsMaxBound `elem` s
                         then pure maxBound
                         else Gen.int (linear 11 (maxBound -1))
    if IsNegative `elem` s
       then if IsMinBound `elem` s
               then pure minBound
               else pure (-i)
       else pure i

intGenTests :: TestTree
intGenTests = testGroup "Spec.Int" $
    fromGroup <$> [
      runGeneratorTestsWhere (Proxy :: Proxy Int) "Int Generator" (Yes :: Formula IntProp)
    ]

instance HasPureTestRunner IntProp Int where
  expect _ = Var IsSmall :&&: Var IsNegative
  script _ i = i < 0 && i >= -10

intPureTests :: TestTree
intPureTests = testGroup "Pure.AcceptsSmallNegativeInts" $
  fromGroup <$> [
    runPureTestsWhere (Proxy :: Proxy Int) "AcceptsSmallNegativeInts" (Yes :: Formula IntProp)
  ]

instance HasPlutusTestRunner IntProp Int where
  expect _ _ = Var IsSmall :&&: Var IsNegative
  script _ i =
    let ii = (fromIntegral i) :: Integer
     in compile (pif (((fromInteger ii) #< ((fromInteger 0) :: Term s PInteger)) #&& (((fromInteger (-10)) :: Term s PInteger) #<= (fromInteger ii))) (pcon PUnit) perror)

intPlutarchTests :: TestTree
intPlutarchTests = testGroup "Plutarch.AcceptsSmallNegativeInts" $
  fromGroup <$> [
    runScriptTestsWhere (Proxy :: Proxy Int) (Proxy :: Proxy IntProp) "AcceptsSmallNegativeInts" Yes
  ]


