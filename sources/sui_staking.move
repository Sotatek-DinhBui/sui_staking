module sui_staking::sui_staking;

use sui::balance::{Self as balance_mod, Balance};
use sui::clock::Clock;
use sui::coin::Coin;
use sui::package;
use sui::sui::SUI;
use sui_staking::staking_config::{Self, StakeConfig};
use sui_staking::user_stake::{Self as user_stake_mod, UserStake};

use fun sui::dynamic_field::add as UID.add;
use fun sui::dynamic_field::borrow as UID.borrow;
use fun sui::dynamic_field::borrow_mut as UID.borrow_mut;

public struct SUI_STAKING has drop {}

public struct StakingWtns has drop {}

public struct Staking<phantom StakedToken> has key {
    id: UID,
    balance: Balance<StakedToken>,
}

public struct AdminCap has key, store {
    id: UID,
}

public struct ConfigKey<phantom Config> has copy, drop, store {}

fun init(otw: SUI_STAKING, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);

    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());

    let mut staking: Staking<SUI> = Staking {
        id: object::new(ctx),
        balance: balance_mod::zero(),
    };

    let config = staking_config::new(StakingWtns {}, 50_000_000);
    staking.id.add(ConfigKey<StakeConfig<StakingWtns>> {}, config);

    transfer::share_object(staking);
}

public fun stake<StakedToken>(
    staking: &mut Staking<StakedToken>,
    amount: Coin<StakedToken>,
    clock: &Clock,
    ctx: &mut TxContext,
): UserStake<StakingWtns> {
    let config: &StakeConfig<StakingWtns> = get_config(staking);

    let user_stake: UserStake<StakingWtns> = user_stake_mod::mint_stake(
        StakingWtns {},
        config.get_reward_rate(),
        amount.value(),
        clock,
        ctx,
    );

    staking.balance.join(amount.into_balance());

    user_stake
}

public fun unstake<StakedToken>(
    staking: &mut Staking<StakedToken>,
    user_stake: UserStake<StakingWtns>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<StakedToken> {
    let reward = user_stake_mod::calculate_reward(&user_stake, clock.timestamp_ms());

    let reward = staking.balance.split(reward).into_coin(ctx);

    user_stake_mod::burn_stake(StakingWtns {}, user_stake);

    reward
}

public fun withdraw<StakedToken>(
    _: &AdminCap,
    staking: &mut Staking<StakedToken>,
    amount: u64,
    ctx: &mut TxContext,
): Coin<StakedToken> {
    let withdrawn_token = staking.balance.split(amount).into_coin(ctx);

    withdrawn_token
}

public fun deposit<StakedToken>(
    _: &AdminCap,
    staking: &mut Staking<StakedToken>,
    amount: Coin<StakedToken>,
) {
    staking.balance.join(amount.into_balance());
}

public fun update_reward_rate<StakedToken>(
    _: &AdminCap,
    self: &mut Staking<StakedToken>,
    new_rate: u64,
) {
    let config: &mut StakeConfig<StakingWtns> = self
        .id
        .borrow_mut(ConfigKey<StakeConfig<StakingWtns>> {});
    staking_config::update_reward_rate(StakingWtns {}, config, new_rate);
}

public fun get_config<Config: store, StakedToken>(self: &Staking<StakedToken>): &Config {
    self.id.borrow(ConfigKey<Config> {})
}
