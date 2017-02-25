{-# LANGUAGE GADTs, OverloadedStrings, InstanceSigs, TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}
-- | Provides actions for Guild API interactions.
module Network.Discord.Rest.Guild
  (
    GuildRequest(..)
  ) where

    import Control.Concurrent.STM
    import Data.Aeson
    import Data.Hashable

    import Data.Text as T
    import Data.Time.Clock.POSIX
    import qualified Control.Monad.State as ST (get, liftIO)

    import Network.Discord.Rest.Prelude
    import Network.Discord.Types as Dc
    import qualified Network.Discord.Rest.HTTP as HTTP


    -- | Data constructor for Guild requests. See 
    --   <https://discordapp.com/developers/docs/resources/guild Guild API>
    data GuildRequest a where
      -- | Returns the new 'Guild' object for the given id
      GetGuild                 :: Snowflake -> GuildRequest Guild
      -- | Modify a guild's settings. Returns the updated 'Guild' object on success. Fires a
      --   Guild Update 'Event'.
      ModifyGuild              :: ToJSON a => Snowflake -> a -> GuildRequest Guild
      -- | delete' a guild permanently. User must be owner. Fires a Guild delete' 'Event'.
      DeleteGuild              :: Snowflake -> GuildRequest Guild
      -- | Returns a list of guild 'Channel' objects
      GetGuildChannels         :: Snowflake -> GuildRequest [Channel]
      -- | Create a new 'Channel' object for the guild. Requires 'MANAGE_CHANNELS' 
      --   permission. Returns the new 'Channel' object on success. Fires a Channel Create
      --   'Event'
      CreateGuildChannel       :: ToJSON a => Snowflake -> a -> GuildRequest Channel
      -- | Modify the positions of a set of channel objects for the guild. Requires 
      --   'MANAGE_CHANNELS' permission. Returns a list of all of the guild's 'Channel'
      --   objects on success. Fires multiple Channel Update 'Event's.
      ModifyChanPosition       :: ToJSON a => Snowflake -> a -> GuildRequest [Channel]
      -- | Returns a guild 'Member' object for the specified user
      GetGuildMember           :: Snowflake -> Snowflake -> GuildRequest Member
      -- | Returns a list of guild 'Member' objects that are members of the guild.
      ListGuildMembers         :: Snowflake -> Range -> GuildRequest [Member]
      -- | Adds a user to the guild, provided you have a valid oauth2 access token
      --   for the user with the guilds.join scope. Returns the guild 'Member' as the body.
      --   Fires a Guild Member Add 'Event'. Requires the bot to have the 
      --   CREATE_INSTANT_INVITE permission.
      AddGuildMember           :: ToJSON a => Snowflake -> Snowflake -> a 
                                    -> GuildRequest Member
      -- | Modify attributes of a guild 'Member'. Fires a Guild Member Update 'Event'.
      ModifyGuildMember        :: ToJSON a => Snowflake -> Snowflake -> a 
                                    -> GuildRequest ()
      -- | Remove a member from a guild. Requires 'KICK_MEMBER' permission. Fires a
      --   Guild Member Remove 'Event'.
      RemoveGuildMember        :: Snowflake -> Snowflake -> GuildRequest ()
      -- | Returns a list of 'User' objects that are banned from this guild. Requires the
      --   'BAN_MEMBERS' permission
      GetGuildBans             :: Snowflake -> GuildRequest [User]
      -- | Create a guild ban, and optionally delete' previous messages sent by the banned
      --   user. Requires the 'BAN_MEMBERS' permission. Fires a Guild Ban Add 'Event'.
      CreateGuildBan           :: Snowflake -> Snowflake -> Integer -> GuildRequest ()
      -- | Remove the ban for a user. Requires the 'BAN_MEMBERS' permissions. 
      --   Fires a Guild Ban Remove 'Event'.
      RemoveGuildBan           :: Snowflake -> Snowflake -> GuildRequest ()
      -- | Returns a list of 'Role' objects for the guild. Requires the 'MANAGE_ROLES'
      --   permission
      GetGuildRoles            :: Snowflake -> GuildRequest [Role]
      -- | Create a new 'Role' for the guild. Requires the 'MANAGE_ROLES' permission.
      --   Returns the new role object on success. Fires a Guild Role Create 'Event'.
      CreateGuildRole          :: Snowflake -> GuildRequest Role
      -- | Modify the positions of a set of role objects for the guild. Requires the 
      --   'MANAGE_ROLES' permission. Returns a list of all of the guild's 'Role' objects
      --   on success. Fires multiple Guild Role Update 'Event's.
      ModifyGuildRolePositions :: ToJSON a => Snowflake -> [a] -> GuildRequest [Role]
      -- | Modify a guild role. Requires the 'MANAGE_ROLES' permission. Returns the 
      --   updated 'Role' on success. Fires a Guild Role Update 'Event's.
      ModifyGuildRole          :: ToJSON a => Snowflake -> Snowflake -> a 
                                    -> GuildRequest Role
      -- | delete' a guild role. Requires the 'MANAGE_ROLES' permission. Fires a Guild Role
      --   delete' 'Event'.
      DeleteGuildRole          :: Snowflake -> Snowflake -> GuildRequest Role
      -- | Returns an object with one 'pruned' key indicating the number of members 
      --   that would be removed in a prune operation. Requires the 'KICK_MEMBERS' 
      --   permission.
      GetGuildPruneCount       :: Snowflake -> Integer -> GuildRequest Object
      -- | Begin a prune operation. Requires the 'KICK_MEMBERS' permission. Returns an
      --   object with one 'pruned' key indicating the number of members that were removed
      --   in the prune operation. Fires multiple Guild Member Remove 'Events'.
      BeginGuildPrune          :: Snowflake -> Integer -> GuildRequest Object
      -- | Returns a list of 'VoiceRegion' objects for the guild. Unlike the similar /voice
      --   route, this returns VIP servers when the guild is VIP-enabled.
      GetGuildVoiceRegions     :: Snowflake -> GuildRequest [VoiceRegion]
      -- | Returns a list of 'Invite' objects for the guild. Requires the 'MANAGE_GUILD'
      --   permission.
      GetGuildInvites          :: Snowflake -> GuildRequest [Invite]
      -- | Return a list of 'Integration' objects for the guild. Requires the 'MANAGE_GUILD'
      --   permission.
      GetGuildIntegrations     :: Snowflake -> GuildRequest [Integration]
      -- | Attach an 'Integration' object from the current user to the guild. Requires the
      --   'MANAGE_GUILD' permission. Fires a Guild Integrations Update 'Event'.
      CreateGuildIntegration   :: ToJSON a => Snowflake -> a -> GuildRequest ()
      -- | Modify the behavior and settings of a 'Integration' object for the guild.
      --   Requires the 'MANAGE_GUILD' permission. Fires a Guild Integrations Update 'Event'.
      ModifyGuildIntegration   :: ToJSON a => Snowflake -> Snowflake -> a -> GuildRequest ()
      -- | delete' the attached 'Integration' object for the guild. Requires the 
      --   'MANAGE_GUILD' permission. Fires a Guild Integrations Update 'Event'.
      DeleteGuildIntegration   :: Snowflake -> Snowflake -> GuildRequest ()
      -- | Sync an 'Integration'. Requires the 'MANAGE_GUILD' permission.
      SyncGuildIntegration     :: Snowflake -> Snowflake -> GuildRequest ()
      -- | Returns the 'GuildEmbed' object. Requires the 'MANAGE_GUILD' permission.
      GetGuildEmbed            :: Snowflake -> GuildRequest GuildEmbed
      -- | Modify a 'GuildEmbed' object for the guild. All attributes may be passed in with
      --   JSON and modified. Requires the 'MANAGE_GUILD' permission. Returns the updated
      --   'GuildEmbed' object.
      ModifyGuildEmbed         :: Snowflake -> GuildEmbed -> GuildRequest GuildEmbed

    instance Hashable (GuildRequest a) where
      hashWithSalt s (GetGuild g)              = hashWithSalt s ("guild"::Text, g)
      hashWithSalt s (ModifyGuild g _)         = hashWithSalt s ("guild"::Text, g)
      hashWithSalt s (DeleteGuild g)           = hashWithSalt s ("guild"::Text, g)
      hashWithSalt s (GetGuildChannels g)      = hashWithSalt s ("guild_chan"::Text, g)
      hashWithSalt s (CreateGuildChannel g _)  = hashWithSalt s ("guild_chan"::Text, g)
      hashWithSalt s (ModifyChanPosition g _)  = hashWithSalt s ("guild_chan"::Text, g)
      hashWithSalt s (GetGuildMember g _)      = hashWithSalt s ("guild_memb"::Text, g)
      hashWithSalt s (ListGuildMembers g _)  = hashWithSalt s ("guild_membs"::Text, g)
      hashWithSalt s (AddGuildMember g _ _)    = hashWithSalt s ("guild_memb"::Text, g)
      hashWithSalt s (ModifyGuildMember g _ _) = hashWithSalt s ("guild_memb"::Text, g)
      hashWithSalt s (RemoveGuildMember g _)   = hashWithSalt s ("guild_memb"::Text, g)
      hashWithSalt s (GetGuildBans g)          = hashWithSalt s ("guild_bans"::Text, g)
      hashWithSalt s (CreateGuildBan g _ _)    = hashWithSalt s ("guild_ban" ::Text, g)
      hashWithSalt s (RemoveGuildBan g _)      = hashWithSalt s ("guild_ban" ::Text, g)
      hashWithSalt s (GetGuildRoles  g)        = hashWithSalt s ("guild_roles"::Text, g)
      hashWithSalt s (CreateGuildRole g)       = hashWithSalt s ("guild_roles"::Text, g)
      hashWithSalt s (ModifyGuildRolePositions g _)
                                               = hashWithSalt s ("guild_roles"::Text, g)
      hashWithSalt s (ModifyGuildRole g _ _)   = hashWithSalt s ("guild_role" ::Text, g)
      hashWithSalt s (DeleteGuildRole g _ )    = hashWithSalt s ("guild_role" ::Text, g)
      hashWithSalt s (GetGuildPruneCount g _)  = hashWithSalt s ("guild_prune"::Text, g)
      hashWithSalt s (BeginGuildPrune    g _)  = hashWithSalt s ("guild_prune"::Text, g)
      hashWithSalt s (GetGuildVoiceRegions g)  = hashWithSalt s ("guild_voice"::Text, g)
      hashWithSalt s (GetGuildInvites g)       = hashWithSalt s ("guild_invit"::Text, g)
      hashWithSalt s (GetGuildIntegrations g)  = hashWithSalt s ("guild_integ"::Text, g)
      hashWithSalt s (CreateGuildIntegration g _)
                                               = hashWithSalt s ("guild_integ"::Text, g)
      hashWithSalt s (ModifyGuildIntegration g _ _)
                                               = hashWithSalt s ("guild_intgr"::Text, g)
      hashWithSalt s (DeleteGuildIntegration g _)
                                               = hashWithSalt s ("guild_intgr"::Text, g)
      hashWithSalt s (SyncGuildIntegration g _)= hashWithSalt s ("guild_sync" ::Text, g)
      hashWithSalt s (GetGuildEmbed g)         = hashWithSalt s ("guild_embed"::Text, g)
      hashWithSalt s (ModifyGuildEmbed g _)    = hashWithSalt s ("guild_embed"::Text, g)

    instance Eq (GuildRequest a) where
      a == b = hash a == hash b

    instance RateLimit (GuildRequest a) where
      getRateLimit req = do
        DiscordState {getRateLimits=rl} <- ST.get
        now <- ST.liftIO (fmap round getPOSIXTime :: IO Int)
        ST.liftIO . atomically $ do
          rateLimits <- readTVar rl
          case lookup (hash req) rateLimits of
            Nothing -> return Nothing
            Just a
              | a >= now  -> return $ Just a
              | otherwise -> modifyTVar' rl (Dc.delete $ hash req) >> return Nothing

      setRateLimit req reset = do
        DiscordState {getRateLimits=rl} <- ST.get
        ST.liftIO . atomically . modifyTVar rl $ Dc.insert (hash req) reset


    instance (FromJSON a) => DoFetch (GuildRequest a) where
      doFetch req = do
        waitRateLimit req
        SyncFetched <$> fetch req


    doRequest :: (FromJSON b) => HTTP.Methods -> GuildRequest b -> IO HTTP.Response
    doRequest (get, HTTP.Post post, HTTP.Put put, HTTP.Patch patch, delete') request = return =<< case request of
          GetGuild chan -> get $ show chan
          ModifyGuild chan patch' -> patch (show chan) patch'
          DeleteGuild chan -> delete' $ show chan
          GetGuildChannels chan -> get (show chan++"/channels")
          CreateGuildChannel chan patch' -> post (show chan++"/channels") patch'
          ModifyChanPosition chan patch' -> patch (show chan ++ "/channels") patch'
          GetGuildMember chan user -> get (show chan++"/members/"++show user)
          ListGuildMembers chan range -> get (show chan++"/members?limit="++toQueryString range)
          AddGuildMember chan user patch' -> put (show chan++"/members/"++show user) patch'
          ModifyGuildMember chan user patch' ->  patch (show chan++"/members/"++show user) patch'
          RemoveGuildMember chan user ->  delete' $ show chan++"/members/"++show user
          GetGuildBans chan -> get (show chan++"/bans")
          CreateGuildBan chan user msg -> let payload = object ["delete-message-days" .= msg]
                                          in put (show chan++"/bans/"++show user) payload
          RemoveGuildBan chan user ->  delete' (show chan++"/bans/"++show user)
          GetGuildRoles chan -> get (show chan++"/roles")
          CreateGuildRole chan -> post (show chan++"/roles") noPayload
          ModifyGuildRolePositions chan pos -> post (show chan++"/roles") pos
          ModifyGuildRole chan role patch' -> post (show chan++"/roles/"++show role) patch'
          DeleteGuildRole chan role ->  delete' (show chan++"/roles/"++show role)
          GetGuildPruneCount chan days -> get (show chan++"/prune?days="++show days)
          BeginGuildPrune chan days -> post (show chan++"/prune?days="++show days) noPayload
          GetGuildVoiceRegions chan -> get (show chan++"/regions")
          GetGuildInvites chan -> get (show chan++"/invites")
          GetGuildIntegrations chan -> get (show chan++"/integrations")
          CreateGuildIntegration chan patch' -> post (show chan++"/integrations") patch'
          ModifyGuildIntegration chan integ patch' -> patch (show chan++"/integrations/"++show integ) patch'
          DeleteGuildIntegration chan integ -> delete' (show chan++"/integrations/"++show integ)
          SyncGuildIntegration chan integ -> post (show chan++"/integrations/"++show integ) noPayload
          GetGuildEmbed chan -> get (show chan++"/embed")
          ModifyGuildEmbed chan embed -> patch (show chan++"/embed") embed
      where
        noPayload = []::[Int]


    fetch :: (FromJSON b) => GuildRequest b -> DiscordM b
    fetch = HTTP.fetch HTTP.Guild doRequest

