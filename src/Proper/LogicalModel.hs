module Proper.LogicalModel
  ( LogicalModel(..)
  , Enumerable(..)
  , enumerateScenariosWhere
  , satisfiesFormula
  , enumerateSolutions
  ) where
import Data.Set (Set)
import qualified Data.Set as Set
import qualified Data.Map as Map
import SAT.MiniSat ( Formula (..), solve_all, satisfiable)

class Enumerable p where
  enumerated :: [p]

instance (Enum p, Bounded p) => Enumerable p where
  enumerated = [minBound..maxBound]

class (Enumerable p, Eq p, Ord p, Show p) => LogicalModel p where
  logic :: Formula p

enumerateScenariosWhere :: forall p . LogicalModel p => Formula p -> [Set p]
enumerateScenariosWhere holds = enumerateSolutions $ logic :&&: holds :&&: allPresentInFormula
  where
    allPresentInFormula :: Formula p
    allPresentInFormula = All (mention <$> (enumerated :: [p]))
    mention :: p -> Formula p
    mention p = Var p :||: Not (Var p)

enumerateSolutions :: LogicalModel p => Formula p -> [Set p]
enumerateSolutions f = fromSolution <$> solve_all f
  where
    fromSolution :: LogicalModel p => Map.Map p Bool -> Set p
    fromSolution m = Set.fromList $ filter isInSet enumerated
      where
        isInSet k = Just True == Map.lookup k m

satisfiesFormula :: forall p . LogicalModel p => Formula p -> Set p -> Bool
satisfiesFormula f s = satisfiable $ f :&&: All (Var <$> set) :&&: None (Var <$> unset)
  where
    set :: [p]
    set = Set.toList s
    unset :: [p]
    unset = filter (`notElem` s) (enumerated :: [p])

