module clicker::treasurehunt { 

    use std::error;
    use std::option::{Self, Option, some, is_some};
    use std::string::{Self, String};
    use std::vector;
    use std::signer;
    use aptos_framework::object::{Self, ConstructorRef, Object};
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table::{Self, Table};
    
    /// Game Status
    const EGAME_INACTIVE: u8 = 0;
    const EGAME_ACTIVE: u8 = 1;
    const EGAME_PAUSED: u8 = 2;

    /// The user is not allowed to do this operation
    const EGAME_PERMISSION_DENIED: u64 = 0;
    /// The game is active now
    const EGAME_IS_ACTIVE_NOW: u64 = 1;
    /// The game is inactive now
    const EGAME_IS_INACTIVE_NOW: u64 = 2;
    /// The game is not ending time
    const EGAME_NOT_ENDING_TIME: u64 = 3;
    /// The game can not pause or resume
    const EGAME_CAN_NOT_PAUSE_OR_RESUME: u64 = 4;
    /// Gui balance is not enough
    const BALANCE_IS_NOT_ENOUGH: u64 = 5;
    /// It is not supported plan
    const NOT_SUPPOTED_PLAN: u64 = 8;

    
    struct GridSize has drop, store, copy {
        width: u8,
        height: u8
    }

    struct UserState has drop, store, copy {
        score: u64,
        grid_state: vector<u64>,
        power: u64,
        progress_bar: u64,
        update_time: u64,
    }

    struct UserScore has drop, store, copy {
        user_address: address,
        score: u64,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct GameState has key{
        status: u8,
        start_time: u64,
        end_time: u64,
        grid_size: GridSize,
        users: u64,
        leaderboard: vector<UserScore>,
        users_list: vector<address>,
        users_state: vector<UserState>
    }

    public entry fun start_event( creator: &signer, start_time: u64, end_time: u64, grid_width: u8, grid_height: u8 ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let current_time = timestamp::now_seconds();

        let status: u8;
        if (start_time <= current_time) {
            status = EGAME_ACTIVE;
        }
        else {
            status = EGAME_INACTIVE;
        };

        if (!exists<GameState>(creator_addr)) {
            move_to(creator, GameState{
                status: 0,
                start_time: 18_446_744_073_709_551_615,
                end_time: 18_446_744_073_709_551_615, 
                grid_size: GridSize {
                    width: 0,
                    height: 0,
                },
                users: 0,
                leaderboard: vector::empty(),
                users_list: vector::empty(),
                users_state: vector::empty(),
            });
        };

        let game_state = borrow_global_mut<GameState>(creator_addr);

        assert!(game_state.status == 0, error::unavailable(EGAME_IS_ACTIVE_NOW));

        game_state.status = status;
        game_state.start_time = start_time;
        game_state.end_time = end_time;
        game_state.grid_size = GridSize {
            width: grid_width,
            height: grid_height
        };
        game_state.users = 0;
        game_state.leaderboard = vector::empty();
        game_state.users_list = vector::empty();
        game_state.users_state = vector::empty();
    }

    public entry fun end_event( creator: &signer ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let game_state = borrow_global_mut<GameState>(creator_addr);
        let current_time = timestamp::now_seconds();

        assert!(game_state.end_time <= current_time, error::unavailable(EGAME_NOT_ENDING_TIME));
        assert!(game_state.status == EGAME_ACTIVE, error::unavailable(EGAME_IS_INACTIVE_NOW));

        game_state.status = EGAME_INACTIVE;
    }

    public entry fun pause_and_resume ( creator: &signer ) acquires GameState {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @clicker, error::permission_denied(EGAME_PERMISSION_DENIED));

        let game_state = borrow_global_mut<GameState>(creator_addr);
        assert!(game_state.status == EGAME_ACTIVE || game_state.status == EGAME_PAUSED, error::unavailable(EGAME_CAN_NOT_PAUSE_OR_RESUME));

        if (game_state.status == EGAME_ACTIVE) {
            game_state.status = EGAME_PAUSED;
        }
        else if (game_state.status == EGAME_PAUSED) {
            game_state.status = EGAME_ACTIVE;
        }
    }

    /**
        purchase powerup
        plan: 1(1.5 times), 2(3 times), 3(5 times)
     */
    // purchase powerup
    public entry fun purchase_powerup ( account: &signer, plan: u8 ) acquires GameState {
        let signer_addr = signer::address_of(account);

        assert!( plan == 1 || plan == 2 || plan == 3, error::unavailable(NOT_SUPPOTED_PLAN));

        if( plan == 1 ) {
            let gui_balance = 250_001; /* add function. get balance */

            assert!(gui_balance >= 250_000, error::unavailable(BALANCE_IS_NOT_ENOUGH));

            let game_state = borrow_global_mut<GameState>(@clicker);

            let (found, index) = vector::index_of(&game_state.users_list, &signer_addr);

            assert!(found == true, error::unavailable(UNREGISTERED_USER));

            /* add function. transfer token  */

            let user_state = vector::borrow_mut(&mut game_state.users_state, index);

            user_state.power = 1;
        }
        else if( plan == 2 ) {
            let gui_balance = 500_001; /* get balance */

            assert!(gui_balance >= 500_000, error::unavailable(BALANCE_IS_NOT_ENOUGH));

            let game_state = borrow_global_mut<GameState>(@clicker);

            let (found, index) = vector::index_of(&game_state.users_list, &signer_addr);

            assert!(found == true, error::unavailable(UNREGISTERED_USER));

            /* add function. transfer token  */

            let user_state = vector::borrow_mut(&mut game_state.users_state, index);

            user_state.power = 2;
        }
        else if ( plan == 3 ) {
            let gui_balance = 650_001; /* get balance */

            assert!(gui_balance >= 650_000, error::unavailable(BALANCE_IS_NOT_ENOUGH));

            let game_state = borrow_global_mut<GameState>(@clicker);

            let (found, index) = vector::index_of(&game_state.users_list, &signer_addr);

            assert!(found == true, error::unavailable(UNREGISTERED_USER));

            /* add function. transfer token  */

            let user_state = vector::borrow_mut(&mut game_state.users_state, index);

            user_state.power = 3;
        }
    }



    
    // public entry fun reward_distribution ( creator: &signer, start_time: u64, end_time: u64, grid_width: u8, grid_height: u8 ) /* acquires GameState */ {

    // }

    // #[view]
    // public fun show_leaderboard () acquires GameState {

    // }

    // #[view]
    // public fun show_player_score ( player: address ) acquires GameState{

    // }

}