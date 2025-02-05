---------------------------------------------------
-------------------- HANDLERS ---------------------
---------------------------------------------------
-- TODO: Implement register
-- Handler: register
-- Registers a txid as an asset to be stamped
-- Tags: 
--  ['Stamp-Register-Asset-TxID'] = The txId of the asset to be registered
Handlers.add(
  'Stamp-Write-Register',
  Handlers.utils.hasMatchingTag('Action', 'Write-Register'),
  function (message)
    return "Register not currently implemented."
    -- Register(message, Assets)
  end
)

----------------------------
------ Stamp Handlers ------
----------------------------

-- Handler: stamp
-- Checks for rewards, credits, clear
-- Stamps a txid
-- If success, superstamps a txid
-- Tags: 
--    ['Stamp-Target-TxID'] = The txId of the asset to be stamped
--    ['Super-Stamp-Quantity'] = (OPTIONAL) The quantity for a super stamp 
Handlers.add(
  'Stamp-Write-Stamp',
  Handlers.utils.hasMatchingTag('Action', 'Write-Stamp'),
  function (message)

    local stampResult = Stamp(message, Stamps, StampsByAddress, StampsByAsset, StampHistory, IsVouched)

    -- If stampResult is nil, then there was an unknown error
    if not stampResult then
      message.reply({ Result = 'Failure', Data = 'Unknown error',  Tags = { ['Data-Source'] = message.Tags['Data-Source'], ['Stamp-Writer'] = message.From, ['Action'] = 'Write-Stamp-Result' } })
      return
    end

    -- If stampResult is 'Stamped.' or 'Not Vouched.', then the stamp was successful. Stamped means the writer is vouched, Not_Vouched means the writer is not vouched.
    -- Otherwise, there was an error during stamping.
    if stampResult ~= 'Stamped.' and stampResult ~= 'Not Vouched.' then
      message.reply({ Result = 'Failure', Data = stampResult,  Tags = { ['Data-Source'] = message.Tags['Data-Source'], ['Stamp-Writer'] = message.From, ['Action'] = 'Write-Stamp-Result' }})
      return
    end

    -- If there was not an error during stamping, return success.
    -- Parse the stamp result
    local Result = 'Success'
    if stampResult == 'Not Vouched.' then
      Result = 'Not_Vouched'
    end

    message.reply({ Result = Result, Tags = { ['Data-Source'] = message.Tags['Data-Source'], ['Stamp-Writer'] = message.From, ['Action'] = 'Write-Stamp-Result' } })

    -- After a stamp, perform a super stamp if possible.
    local superStampResult = SuperStamp(message, Balances, Credits, IsAtomicAsset)

    -- If super stamping was successful, return success.
    if superStampResult == 'Super Stamped.' then
      message.reply({ Result = 'Success', Tags = { ['Data-Source'] = message.Tags['Data-Source'], ['Stamp-Writer'] = message.From, ['Super-Stamp-Quantity'] = message.Tags['Super-Stamp-Quantity'], ['Action'] = 'Write-Super-Stamp-Result' }})
    end
  end
)


-- Handler: balance
-- Returns balance of an address
-- Tags: 
--    ['Recipient'] | ['Target'] = The address to get the balance of
Handlers.add(
  'Stamp-Read-Balance',
  Handlers.utils.hasMatchingTag('Action', 'Balance'),
  function (message)
    local balanceResult, from = Balance(message, Balances)
    if not balanceResult then
      message.reply({ Result = 'Error', Tags = { ['Error'] = 'Unknown error' } })
    elseif balanceResult == 'Not Validated.' or not from then
      message.reply({ Result = 'Error', Tags = { ['Error'] = 'Invalid Target' } })
    else
      message.reply({ Result = 'Success', Tags = { ['Balance'] = balanceResult, ['Target'] = from, ['Ticker'] = Ticker } })
    end
  end
)

-- Handler: balances
-- Returns all balances
-- Tags: NONE
Handlers.add(
  'Stamp-Read-Balances',
  Handlers.utils.hasMatchingTag('Action', 'Balances'),
  function (message)
    message.reply({ Result = 'Success', Data = json.encode(Balances) })
  end
)

-- Handler: transfer
-- Transfer balance between addresses
-- Tags:
--    ['Recipient'] = The address to transfer balance to
--    ['Quantity'] = The quantity of balance to transfer
Handlers.add(
  'Stamp-Write-Transfer',
  Handlers.utils.hasMatchingTag('Action', 'Transfer'),
  function (message)
    local transferResult = Transfer(message, Balances)
    if transferResult ~= 'Transferred.' then
      message.reply({ Action = 'Transfer-Error', ['Message-Id'] = message.Id, Error = 'Insufficient Balance!' })
    end
  end
)

-- Handler: Allow
-- Add quantity to claimable for later claiming by target address
-- Tags: 
--    ['Allow-Target'] = The address to allow claiming
--    ['Allow-Quantity'] = The amount of claimable to allow
Handlers.add(
  'Stamp-Write-Allow',
  Handlers.utils.hasMatchingTag('Action', 'Write-Allow'),
  function (message)
    Allow(message, Balances, Claimables)
  end
)


-- Handler: Claim
-- Claim claimable quantity
-- Tags: 
--    ['Claim-Quantity'] = The amount to claim
--    ['Claim-TxID'] = The txID from which to claim
Handlers.add(
  'Stamp-Write-Claim',
  Handlers.utils.hasMatchingTag('Action', 'Write-Claim'),
  function (message)
    Claim(message, Claimables, Balances)
  end
)

Handlers.add(
  'Stamp-Read-Stamps-By-Asset',
  Handlers.utils.hasMatchingTag('Action', 'Read-Stamps-By-Asset'),
  function (message)
    local fn = ReadStampsByAsset
    if message.Tags['Data-Sources'] then
      fn = ReadStampsByAssets
    end
    local stamps = fn(message, function (operation, variables)
      return Server:resolve(operation, variables)
    end)
    if not stamps then
      message.reply({ Result = 'Error', Data = 'Unknown error' })
    elseif type(stamps) == "string" then
      message.reply({ Result = 'Error', Data = stamps })
    else
      message.reply({ Result = 'Success', Data = stamps })
    end
  end
)

Handlers.add(
  'Stamp-Read-Stamps-By-Address',
  Handlers.utils.hasMatchingTag('Action', 'Read-Stamps-By-Address'),
  function (message)
    local stamps = ReadStampsByAddress(
      message,
      function (operation, variables)
        return Server:resolve(operation, variables)
      end
    )
    if not stamps then
      message.reply({ Result = 'Error', Data = 'Unknown error' })
    elseif type(stamps) == "string" then
      message.reply({ Result = 'Error', Data = stamps })
    else
      message.reply({ Result = 'Success', Data = stamps })
    end
  end
)

----------------------------
-------- Stamp Cron --------
----------------------------
Handlers.add(
  'Stamp-Cron-Rewards',
  Handlers.utils.hasMatchingTag('Action', 'Cron'),
  function (message)
    local BlockHeight = message["Block-Height"]
    local rewardResult = Reward(BlockHeight, LastReward, Balances, Stamps, StampHistory)
    if rewardResult == 'Rewarded.' then
      LastReward = BlockHeight
    end
    Credit(BlockHeight, Credits, Balances)
    Bound(StampHistory, MAXIMUM_STAMPS)
  end
)

----------------------------
------- Info Handler -------
----------------------------
Handlers.add(
  'info',
  Handlers.utils.hasMatchingTag('Action', 'Info'),
  function(msg)
    if msg.reply then
      msg.reply({
        Name = Name,
        Ticker = Ticker,
        Logo = Logo,
        Denomination = tostring(Denomination),
        Data = json.encode({
          Name = Name,
          Ticker = Ticker,
          Denomination = tostring(Denomination),
          Balances = Balances
        })
      })
    else
      Send({
        Target = msg.From, 
        Name = Name,
        Ticker = Ticker,
        Logo = Logo,
        Denomination = tostring(Denomination),
        Data = json.encode({
          Name = Name,
          Ticker = Ticker,
          Denomination = tostring(Denomination),
          Balances = Balances
        })
      })
  end
end)
