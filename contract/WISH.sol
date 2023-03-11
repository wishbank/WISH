// SPDX-License-Identifier: Apache License 2.0
/*
 * Wishbank Smart Contract Library.  Copyright © 2023 by WISHBANK Creation Team.
 * Author: GreatWisher
 */
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ABDKMath64x64.sol";

contract WISH is ERC20 {
    /* WISH  starts at $0.00000001 on 2023 Mar 6th, enriches 100m times till 2033 Jan 21st, and stablizes at $1.00000005841 */
    using SafeERC20 for ERC20;
    mapping(address => bool) public isUSD;
    mapping(address => uint256) public Decimals;
    uint256 public constant launchTime = 1678104000; /* Mon Mar 06 2023 12:00:00 GMT+0000 */
    uint256 public constant stableTime = 1989925200; /* Fri Jan 21 2033 13:00:00 GMT+0000 */
    address private constant wishFundationAddr = 0x709D83004eB79Cf752B5D4f021d3652c97Ad1561;/* wishbank.eth*/

    constructor(
        address usdt,
        uint256 usdtDecimal,
        address usdc,
        uint256 usdcDecimal,
        address busd,
        uint256 busdDecimal,
        address dai,
        uint256 daiDecimal
    ) ERC20("WISH", "WISH") {
        isUSD[usdt] = true;
        Decimals[usdt] = usdtDecimal;
        isUSD[usdc] = true;
        Decimals[usdc] = usdcDecimal;
        isUSD[busd] = true;
        Decimals[busd] = busdDecimal;
        isUSD[dai] = true;
        Decimals[dai] = daiDecimal;
    }

    function convert6To18(uint256 amount, uint256 decimal)
        public
        pure
        returns (uint256)
    {
        if (decimal == 6) return amount * 1e12;

        return amount;
    }

    function convert18To6(uint256 usd, uint256 decimal)
        public
        pure
        returns (uint256)
    {
        if (decimal == 6) return usd / 1e12;

        return usd;
    }

    function getWishFundationAddress() public pure returns (address) {
        return wishFundationAddr;
    }

    /**
     * The current price of WISH is always 6.4428653X of the price a year ago
     *   y = 6.4428653^(ticktock / 365 days)
     */
    function getPrice() public view returns (uint256) {
        uint256 ticktock;

        if (block.timestamp <= launchTime) return 10000000000; /* WISH price stablizes at $0.00000001 before 2023 Mar 6 */
        if (block.timestamp >= stableTime) return 1000000058410266000; /* WISH price stablizes at $1.00000005841 after 2033 Jan 21 */

        ticktock = block.timestamp - launchTime;

        int128 base = ABDKMath64x64.div(
            ABDKMath64x64.fromUInt(64428653),
            ABDKMath64x64.fromUInt(10000000)
        );
        int128 exponential = ABDKMath64x64.div(
            ABDKMath64x64.fromUInt(ticktock),
            ABDKMath64x64.fromUInt(365 days)
        );

        /**
         * Basic logarithm rule:
         *   x = a^(log_a(x))
         * And deduce it:
         *   x^y = a^(y*log_a(x))
         * When a equals 2
         *   x^y = 2^(y*log_2(x))
         */
        return
            ABDKMath64x64.mulu(
                ABDKMath64x64.exp_2(
                    ABDKMath64x64.mul(exponential, ABDKMath64x64.log_2(base))
                ),
                1e10
            );
    }

    function Buy(address usd, uint256 amount) external returns (bool) {
        require(isUSD[usd], "USD ERROR");
        uint256 _commissionFee = ((amount * 5) / 100);
        uint256 remain = amount - _commissionFee;

        ERC20(usd).safeTransferFrom(
            msg.sender,
            getWishFundationAddress(),
            _commissionFee
        );
        ERC20(usd).safeTransferFrom(msg.sender, address(this), remain);

        remain = convert6To18(remain, Decimals[usd]);
        uint256 wishes = (remain * 1e18) / getPrice();

        _mint(msg.sender, wishes);

        return true;
    }

    function Sell(address usd, uint256 wishes) external returns (bool) {
        require(isUSD[usd], "USD ERROR");

        _burn(msg.sender, wishes);

        uint256 _usd = (wishes * getPrice()) / 1e18;
        _usd = convert18To6(_usd, Decimals[usd]);
        uint256 _commissionFee = ((_usd * 2) / 10);
        uint256 _remain = _usd - _commissionFee;

        ERC20(usd).safeTransfer(getWishFundationAddress(), _commissionFee);
        ERC20(usd).safeTransfer(msg.sender, _remain);
        return true;
    }

    function burn(uint256 wishes) external {
        _burn(msg.sender, wishes);
    }
}
