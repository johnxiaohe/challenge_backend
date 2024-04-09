// import CycleLedger "canister:cycle-ledger";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Ledger "ledgers";
import Trie "mo:base/Trie";
import Nat "mo:base/Nat";


shared actor class() = this {

  type Account = Ledger.Account;
  type BlockIndex = Ledger.BlockIndex;
  type TransferArg = Ledger.TransferArgs;
  type TransferFromArgs = Ledger.TransferFromArgs;
  type LedgerActor = Ledger.Self;

  type Trie<K, V> = Trie.Trie<K, V>;
  type Key<K> = Trie.Key<K>;
  // book
  private stable var deposit: Trie<Text, Nat> = Trie.empty();
  public shared func getDeposits(id: Text, token: Text): async(Nat) {
    let userkey = id # "." # token;
    var value = Trie.get(deposit, key userkey, Text.equal);
    switch(value){
      case(null){ 0 };
      case(?value){
        value;
      };
    };
  };
  // deposits
  public shared ({caller}) func deposits(amount: Nat, token: Text): async Result.Result<Nat, Text>{
    let ledger: LedgerActor = actor(token);
    let userkey = Principal.toText(caller) # "." # token;

    // 查看之前是否有存款
    var current = 0;
    var value = Trie.get(deposit, key userkey, Text.equal);
    switch(value){
      case(null){};
      case(?value){
        current := value;
      };
    };

    let transferFromArgs : TransferFromArgs = {
      from = {owner=caller; subaccount=null};
      memo = null;
      amount = amount;
      spender_subaccount = null;
      fee = null;
      to = { owner = Principal.fromActor(this); subaccount = null };
      created_at_time = null;
    };
    try {
      // initiate the transfer
      let transferResult = await ledger.icrc2_transfer_from(transferFromArgs);

      // check if the transfer was successfull
      switch (transferResult) {
        case (#Err(transferError)) {
          return #err("Couldn't transfer funds:\n" # debug_show (transferError));
        };
        case (#Ok(blockIndex)) { 
          deposit := Trie.put(deposit, key userkey, Text.equal, current + amount).0;
          return #ok current 
        };
      };
    } catch (error : Error) {
      // catch any errors that might occur during the transfer
      return #err("Reject message: " # Error.message(error));
    };
  };

  // withdrawals
  public shared ({caller}) func withdrawals(amount: Nat, token: Text): async Result.Result<Nat, Text>{
    let ledger: LedgerActor = actor(token);
    let userkey = Principal.toText(caller) # "." # token;

        // 查看之前是否有存款
    var current = 0;
    var value = Trie.get(deposit, key userkey, Text.equal);
    switch(value){
      case(null){
        return #err("Need deposit first\n");
      };
      case(?value){
        current := value;
      };
    };

    if (Nat.less(current, amount)) {
      return #err("deposit is less\n");
    };

    if (Nat.less(current, 0)) {
      return #err("error withdrawals amount\n");
    };


    let transferArgs : TransferArg = {
      memo = null;
      amount = amount;
      from_subaccount = null;
      fee = null;
      to = { owner = caller; subaccount = null };
      created_at_time = null;
    };
    try {
      // initiate the transfer
      let transferResult = await ledger.icrc1_transfer(transferArgs);

      // check if the transfer was successfull
      switch (transferResult) {
        case (#Err(transferError)) {
          return #err("Couldn't transfer funds:\n" # debug_show (transferError));
        };
        case (#Ok(blockIndex)) { 
          deposit := Trie.put(deposit, key userkey, Text.equal, (current - amount)).0;
          return #ok blockIndex 
        };
      };
    } catch (error : Error) {
      // catch any errors that might occur during the transfer
      return #err("Reject message: " # Error.message(error));
    };
  };

  func key(t: Text) : Key<Text> { { hash = Text.hash t; key = t } };
};


