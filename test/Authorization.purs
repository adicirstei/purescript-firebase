module Test.Authorization where

import Prelude (Unit, bind, ($), pure)

import Control.Monad.Aff (forkAff,later', launchAff, attempt)
import Control.Monad.Aff.Par (Par(..), runPar)
import Control.Monad.Aff.AVar (AVAR(), makeVar, takeVar, putVar)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Exception (EXCEPTION(), message)
import Control.Alt ((<|>))
import Data.Maybe (Maybe(Just))
import Data.Either (either)
import Web.Firebase.Types as FBT
import Web.Firebase (EventType(..),once)
import Test.Spec                  (describe, it, Spec())
import Test.Spec.Assertions       (shouldEqual)
import Test.Spec.Assertions.Aff (expectError)
import Web.Firebase.Monad.Aff (onceValue, on)

authorizationSpec :: forall eff. FBT.Firebase -> Spec (firebase :: FBT.FirebaseEff, err :: EXCEPTION, avar :: AVAR | eff ) Unit
authorizationSpec forbiddenRef = do
    describe "Understanding AVar and Par" do
      it "can write to a var" do
        respVar <- makeVar
        handle <- forkAff (later' 100 $ putVar respVar true)
        actual <- takeVar respVar
        actual `shouldEqual` true
      it "can race two vars manually" do
        respVar <- makeVar
        handle <- forkAff (later' 100 $ putVar respVar "fast")
        handleSlow <- forkAff (later' 200 $ putVar respVar "slow")
        actual <- takeVar respVar
        actual `shouldEqual` "fast"
      it "can race two vars with an alternative" do
        let fast = (later' 100 $ pure "fast")
            slow = (later' 200 $ pure "slow")
        actual <- runPar (Par fast <|> Par slow)
        actual `shouldEqual` "fast"
    describe "Authorization" do
      describe "once() on forbidden location" do
        it "with Eff calls an error callback" do
          respVar <- makeVar
          handle  <- liftEff $ once ChildAdded (\snap -> launchAff $ putVar respVar "unexpected sucess") (Just (\_ -> launchAff $ putVar respVar "child forbidden")) forbiddenRef
          actual <- takeVar respVar
          actual `shouldEqual` "child forbidden"

        it "with Aff throws an error" do
           e <- attempt $ onceValue forbiddenRef  -- catch error thrown and assert
           either (\err -> (message err) `shouldEqual` "permission_denied: Client doesn't have permission to access the desired data.\n | firebase code: | \n PERMISSION_DENIED") (\_ -> "expected an error to be thrown" `shouldEqual` "but was not") e
      describe "on() at forbidden location" do
        it "ChildAdded with Aff throws an error" do
          expectError $ on ChildAdded forbiddenRef
        it "ChildRemoved with Aff throws an error" do
          expectError $ on ChildRemoved forbiddenRef
        it "ChildChanged with Aff throws an error" do
          expectError $ on ChildChanged forbiddenRef
        it "ChildMoved with Aff throws an error" do
          expectError $ on ChildMoved forbiddenRef
