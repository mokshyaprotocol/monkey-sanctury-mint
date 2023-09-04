module sanctury::sanctury {
    use std::signer;
    use std::bcs;
    use std::hash;
    use std::vector;
    use aptos_std::from_bcs;
    use std::string::{Self, String};
    use aptos_framework::object::{Self,Object};
    use aptos_framework::timestamp;
    use aptos_token_objects::aptos_token::{Self,AptosToken,AptosCollection};
    use aptos_token_objects::royalty;
    use aptos_token_objects::collection;
    use aptos_framework::account;
    use aptos_framework::coin::{Self};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table::{Self, Table};

    struct MintInfo has key{
        base_uri:String,
        last_mint:u64,
        //treasury_cap
        treasury_cap:account::SignerCapability,
        resource_address:address,
        price:u64,
        collection_name:String,
        description:String,
        rankings: Table<vector<u8>,u64>, 
        }
    // ERRORS 
    const ENO_NOT_MODULE_CREATOR:u64=0;
    const ENO_KEYS_MAX_VALUE_UNEQUAL:u64=1;
    const ENO_ALREADY_CLAIMED_OR_NOT_ALLOWED:u64=2;

    public entry fun initiate_collection(
        account: &signer,
        collection:String,
        description:String,
        base_uri:String,
        price:u64,
        royalty_numerator:u64,
        royalty_denominator:u64)
    {
        let owner_addr = signer::address_of(account);
        assert!(owner_addr==@sanctury,ENO_NOT_MODULE_CREATOR);
        let (resource, resource_cap) = account::create_resource_account(account, bcs::to_bytes(&collection));
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
        let resource_address = signer::address_of(&resource);
        let flag= true;
        aptos_token::create_collection(
            &resource_signer_from_cap,
            description,
            500,
            collection,
            base_uri,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            royalty_numerator, //numerator
            royalty_denominator, //denominator
        );
        move_to<MintInfo>(account,
                MintInfo{
                base_uri:base_uri,
                last_mint:0,
                treasury_cap:resource_cap,
                resource_address:resource_address,
                price:price,
                collection_name:collection,
                description:description,
                rankings:table::new<vector<u8>,u64>(),
        });
    }
    public entry fun add_rankings(
        module_owner:&signer,
        rankings:vector<address>,
    )acquires MintInfo
    {
            let owner_addr = signer::address_of(module_owner);
            assert!(owner_addr==@sanctury,ENO_NOT_MODULE_CREATOR);
            let mint_info = borrow_global_mut<MintInfo>(owner_addr);
            // assert!(vector::length(&rankings)==500,ENO_KEYS_MAX_VALUE_UNEQUAL);
            let len = vector::length(&rankings);
            let i =1;
            while(i<=len)
            {
                let x = bcs::to_bytes<address>(vector::borrow(&rankings,i));
                table::add(&mut mint_info.rankings,bcs::to_bytes<address>(vector::borrow(&rankings,i)) , i);
                i=i+1;
            };
    }
    public entry fun mint_sanctury(
            receiver: &signer,
    )acquires MintInfo
        {
            let receiver_addr = signer::address_of(receiver);
            assert!(exists<MintInfo>(@sanctury),12);
            let mint_info = borrow_global_mut<MintInfo>(@sanctury);
            let resource_signer_from_cap = account::create_signer_with_capability(&mint_info.treasury_cap);
            assert!(table::contains(& mint_info.rankings,bcs::to_bytes<address>(&receiver_addr)),ENO_ALREADY_CLAIMED_OR_NOT_ALLOWED);
            let mint_position = table::remove(&mut mint_info.rankings,bcs::to_bytes<address>(&receiver_addr));
            let baseuri = mint_info.base_uri;
            string::append(&mut baseuri,num_str(mint_position));
            let token_name = mint_info.collection_name;
            string::append(&mut token_name,string::utf8(b" #"));
            string::append(&mut token_name,num_str(mint_position));
            string::append(&mut baseuri,string::utf8(b".json"));
            let minted_token= aptos_token::mint_token_object(
                &resource_signer_from_cap,
                mint_info.collection_name,
                mint_info.description,
                token_name,
                baseuri,
                vector::empty<String>(),
                vector::empty<String>(),
                vector::empty());
            object::transfer(&resource_signer_from_cap, minted_token, receiver_addr);
            coin::transfer<AptosCoin>(receiver,@sanctury , mint_info.price);   
        }


    inline fun collection_object(creator: &signer, name: &String): Object<AptosCollection> {
        let collection_addr = collection::create_collection_address(&signer::address_of(creator), name);
        object::address_to_object<AptosCollection>(collection_addr)
    }
    fun num_str(num: u64): String
    {
        let v1 = vector::empty();
        while (num/10 > 0){
            let rem = num%10;
            vector::push_back(&mut v1, (rem+48 as u8));
            num = num/10;
        };
        vector::push_back(&mut v1, (num+48 as u8));
        vector::reverse(&mut v1);
        string::utf8(v1)
    }
}