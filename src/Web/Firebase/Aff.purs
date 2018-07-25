module Web.Firebase.Aff
-- | Firebase API translated to AFF
-- | mostly functions from standard API
-- | convenience functions not part of the api can be found in
-- | Web.Firebase.Aff.Read
(
  child
, convertError
, key
, offLocation
, on
, once
, onceValue
, push
, set
, fb2error
, firebaseErrToString
, toString
, remove
, noOpCanceler
)
where

import Control.Monad.Error.Class (throwError)
import Control.Monad((>>=))
import Data.Function(const)
import Data.Maybe (Maybe(Just, Nothing))
import Data.Nullable (toNullable)
import Data.Either(Either(..))
import Effect (Effect)
import Effect.Aff (Aff, Canceler(..), makeAff)
import Effect.Class (liftEffect)
import Effect.Exception (Error, error)
import Foreign (Foreign, unsafeToForeign)
import Prelude (Unit, pure, ($), (<<<))
import Web.Firebase as FB
import Web.Firebase.Types as FBT

import Data.Unit(unit)

-- | Inspired by its Eff relative.
-- Throw takes a message and throws a MonadError in Aff with that message
throw :: forall a. String -> Aff a
throw = throwError <<< error

foreign import fb2error :: FBT.FirebaseErr -> Error
foreign import firebaseErrToString :: FBT.FirebaseErr -> String

-- | Gets a Firebase reference for the location at the specified relative path.
-- https://www.firebase.com/docs/web/api/firebase/child.html

child :: FBT.Key ->
       FBT.Firebase ->
       Aff FBT.Firebase
child aKey ref = liftEffect $ FB.child aKey ref

-- | Returns the key of the current firebase reference
-- throws a MonadError if there was no key (i.e. when you ask for the key of the root reference, according to
-- https://www.firebase.com/docs/web/api/firebase/key.html
-- We made it an error, because asking a key of the root reference is a programming error, and should normally not happen.
-- One could specialize this in a Firebase type that can't be the root, or return '/' as the key.
key :: FBT.Firebase ->
       Aff FBT.Key
key fb = do
  let mKey = FB.key fb
  case mKey of
       Nothing -> throw "Key was null. Did you ask key of root reference?"
       Just k -> pure k

-- | This is the start of a more 'purescript-ish' interface than can be found in Web.Firebase
-- We use the Aff monad to eliminate callback hell
-- This way we can deal with callbacks that are called once.
-- We envision Web.Firebase.Signals to generate signals from callbacks that can be called multiple times

-- TODO this works for value, but will ignore the prevChild argument for onChildAdded etc.
-- on :: FB.EventType ->
--       FBT.Firebase ->
--       Aff FBT.DataSnapshot
-- on etype fb = makeAff (\eb cb -> FB.on etype cb (convertError eb) fb)
on :: FB.EventType ->
      FBT.Firebase ->
      Aff FBT.DataSnapshot
on etype fb = makeAff (\fn -> FB.on etype (fn <<< Right) (convertError (fn <<< Left)) fb >>= const (pure noOpCanceler))


noOpCanceler = Canceler $ const $ pure unit



-- convert firebase error to purescript Error in javascript
-- see .js file for firebase Error documentation
convertError :: (Error -> Effect Unit) ->
	 FBT.FirebaseErr ->
         Effect Unit
convertError errorCallback firebaseError = errorCallback (fb2error firebaseError)

-- We also take the liberty to write more specific functions, e.g. once and on() in firebase have 4 event types. we get better error messages and code completion by making specific functions, e.g.
-- onvalue and onchildadded instead of on(value) and on(childAdded)

once :: FB.EventType -> FBT.Firebase -> Aff FBT.DataSnapshot
once eventType root = makeAff (\fn ->
		                FB.once eventType (fn <<< Right) (convertError (fn <<< Left)) root  >>= const (pure noOpCanceler))

-- | write a value under a new generated key to the database
-- returns the firebase reference generated
push :: Foreign -> FBT.Firebase -> Aff FBT.Firebase
push value ref = makeAff (\fn -> FB.pushA value (fn <<< Right) (convertError (fn <<< Left)) ref  >>= const (pure noOpCanceler))

set :: Foreign -> FBT.Firebase ->  Aff Unit
set value ref = makeAff (\fn -> FB.setA value (fn <<< Right) (convertError (fn <<< Left)) ref  >>= const (pure noOpCanceler))

-- | Extra functions not part of firebase api, grown out of our use
offLocation :: FBT.Firebase -> Aff Unit
offLocation = liftEffect <<< FB.offSimple

onceValue :: FBT.Firebase -> Aff FBT.DataSnapshot
onceValue root = once FB.Value root

-- | Get the absolute URL for this location -  https://firebase.google.com/docs/reference/js/firebase.database.Reference#toString

toString :: FBT.Firebase -> Aff String
toString = liftEffect <<< FB.toString

-- | remove data below ref
-- (firebase will also remove the path to ref probably)
-- not a separate function on the API, but 'set null' which is not pretty in purescript
-- nor easy to understand
remove :: FBT.Firebase -> Aff Unit
remove ref = set foreignNull ref
             where foreignNull = unsafeToForeign $ toNullable $ Nothing
