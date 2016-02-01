module Test.DataSnapshotSpec (dataSnapshotSpec) where

import Prelude (Unit, bind, ($), (>>=), (>=), pure)

import Control.Monad.Aff (Aff())
import Control.Monad.Eff.Class (liftEff)
import Control.Monad (unless)
import Data.Maybe (Maybe(Just))
import Web.Firebase as FB
import Web.Firebase.Monad.Aff (onceValue)
import Web.Firebase.UnsafeRef (refFor)
import Web.Firebase.DataSnapshot as D
import Web.Firebase.Types as FBT
import Test.Spec                  (describe, pending, it, Spec())
import Test.Spec.Runner           (Process())
import Test.Spec.Assertions       (fail, shouldEqual)

eSnapshot :: forall eff. Aff (firebase :: FBT.FirebaseEff | eff) FBT.DataSnapshot
eSnapshot = snapshotFor "entries"

doesNotExist :: forall eff. Aff (firebase :: FBT.FirebaseEff | eff) FBT.DataSnapshot
doesNotExist = snapshotFor "entries/doesnotexist"

snapshotFor :: forall eff. String -> Aff (firebase :: FBT.FirebaseEff | eff) FBT.DataSnapshot
snapshotFor location  = getRoot >>= \r -> (liftEff $ FB.child location r) >>= onceValue


getRoot :: forall eff. Aff (firebase :: FBT.FirebaseEff | eff) FBT.Firebase
getRoot = refFor "https://purescript-spike.firebaseio.com/"

expect :: forall r. Boolean -> Aff r Unit
expect condition = unless condition $ fail "false ≠ true"

dataSnapshotSpec ::  forall eff. FBT.DataSnapshot -> Spec ( process :: Process, firebase :: FBT.FirebaseEff | eff) Unit
dataSnapshotSpec snapshot =
    describe "DataSnapshot" do
      -- literal API
      -- the difference between snapshots and refs is somewhat confusing
      it "can tell us the number of children" do
        let numChildren = D.numChildren snapshot
        expect (numChildren >= 1)

      it "can tell us a child does not exist" do
        (D.hasChild snapshot "doesnotexist")  `shouldEqual` false

      it "can tell us a child exists" do
        expect $ D.hasChild snapshot "-K7GbWeFHfJXlun7szRe" -- type Key = String ?

      it "can tell us the location at the snapshot exists" do
        expect $ (D.exists snapshot)

      it "can tell us it has children" do
        expect $ D.hasChildren snapshot

      pending "says the key of the database root is Nothing" {-
        -- Root has become inacessible due to permission tests :-( not sure how to test Nothing for key now
        do
        rs <- rootSnapshot
        let key = D.key rs
        key `shouldEqual` Nothing
      -}
      it "says the key of /entries is entries" do
        let key = D.key snapshot
        key `shouldEqual` (Just "entries")

      it "it can not tell us the location at the snapshot does not exist" do
        sn <- doesNotExist
        (D.exists sn) `shouldEqual` false
        -- /entries/doesnotexist
        -- perhaps it can now, it might just have been an error callback with an additional () missing.
      pending "can it say the value of child \"entries\" is Nothing?"
        -- this relies on trying to read a firebase ref with once, and that 'works' by never being called back
      pending "it can give us a snapshot of one of its children"
      -- implement forEach callback that returns true after first call, so it terminates
      -- put that callback into Aff, so we can wait for the result
      -- with Aff, and the Aff variable, we can retrieve a list.