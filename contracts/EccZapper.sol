// SPDX-License-Identifier: AGPLv3                                                                                                                   
pragma solidity 0.8.17;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IEmpireRouter {
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

}

/**
    @title EccZapper
    @author Empire Capital (Tranquil Flow)
    @dev Creates LP tokens from native coin
*/
contract EccZapper is Ownable {
    IEmpireRouter public router;

    event TokenLiquidityAdded(
        uint lpTokensCreated,
        address tokenA,
        address tokenB,
        uint tokenAadded,
        uint tokenBadded
    );
    event ETHLiquidityAdded(
        uint lpTokensCreated,
        address token,
        uint tokenAdded,
        uint ETHadded
    );

    constructor (address _router) {
        router = IEmpireRouter(_router);
    }

    receive() external payable { }

    function zapEthForTokenPair(address tokenA, address tokenB) external payable {
        (bool sent,) = address(this).call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        uint halfETH = address(this).balance/2;
        address[] memory path = new address[](2);

        // Swap 50% ETH for tokenA
        path[0] = address(router.WETH());
        path[1] = address(tokenA);
        uint[] memory amounts1 = router.swapExactETHForTokens{value: halfETH}(
            0,
            path,
            address(this),
            block.timestamp + 10
        );
        uint tokenAamount = amounts1[1];

        // Swap 50% ETH for tokenB
        path[0] = address(router.WETH());
        path[1] = address(tokenB);
        uint[] memory amounts2 = router.swapExactETHForTokens{value: halfETH}(
            0,
            path,
            address(this),
            block.timestamp + 10
        );
        uint tokenBamount = amounts2[1];

        // Create & Send LP
        IERC20(tokenA).approve(address(router), tokenAamount);
        IERC20(tokenB).approve(address(router), tokenBamount);
        (uint _tokenAadded, uint _tokenBadded, uint _lpTokensCreated) = router.addLiquidity(
            tokenA,
            tokenB,
            tokenAamount,
            tokenBamount,
            0,
            0,
            msg.sender,
            block.timestamp + 10
        );

        emit TokenLiquidityAdded(
            _lpTokensCreated,
            tokenA,
            tokenB,
            _tokenAadded,
            _tokenBadded
        );
    }

    function zapEthForEthPair(address token) external payable {
        (bool sent,) = address(this).call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        uint halfETH = address(this).balance/2;
        address[] memory path = new address[](2);

        // Swap 50% ETH for Token
        path[0] = address(router.WETH());
        path[1] = address(token);
        uint[] memory amounts1 = router.swapExactETHForTokens{value: halfETH}(
            0,
            path,
            address(this),
            block.timestamp + 10
        );
        uint tokenAmount = amounts1[1];

        // Create & Send LP
        IERC20(token).approve(address(router), tokenAmount);
        (uint _tokenAmount, uint _ETHamount, uint _lpTokensCreated) = router.addLiquidityETH
            {value: halfETH}(
            token,
            tokenAmount,
            0,
            0,
            msg.sender,
            block.timestamp + 10
        );

        emit ETHLiquidityAdded(
            _lpTokensCreated,
            token,
            _tokenAmount,
            _ETHamount
        );
    }

    function makeLiquidityForTokenPair(
        address tokenA,
        address tokenB,
        uint tokenAamount,
        uint tokenBamount
        ) external {

        // Send Tokens to contract
        require(IERC20(tokenA).transferFrom(msg.sender, address(this), tokenAamount), "Token A transfer failed");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), tokenBamount), "Token B transfer failed");

        // Create & Send LP
        require(IERC20(tokenA).approve(address(router), type(uint).max), "Token A approve failed");
        require(IERC20(tokenB).approve(address(router), type(uint).max), "Token B aprove failed");
        (uint _tokenAadded, uint _tokenBadded, uint _lpTokensCreated) = router.addLiquidity(
            tokenA,
            tokenB,
            tokenAamount,
            tokenBamount,
            0,
            0,
            msg.sender,
            block.timestamp + 10
        );

        emit TokenLiquidityAdded(
            _lpTokensCreated,
            tokenA,
            tokenB,
            _tokenAadded,
            _tokenBadded
        );
    }

    function makeLiquidityForEthPair(address token, uint tokenAmount) external payable {
        // Send Token to contract
        require(IERC20(token).transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");

        // Create & Send LP
        require(IERC20(token).approve(address(router), type(uint).max), "Token approval failed");
        (uint _tokenAmount, uint _ETHamount, uint _lpTokensCreated) = router.addLiquidityETH
            {value: msg.value}(
            token,
            tokenAmount,
            0,
            0,
            msg.sender,
            block.timestamp + 10
        );

        emit ETHLiquidityAdded(
            _lpTokensCreated,
            token,
            _tokenAmount,
            _ETHamount
        );
    }

    function recover(address token) external onlyOwner {
        if (token == 0x0000000000000000000000000000000000000000) {
            payable(msg.sender).call{value: address(this).balance}("");
        } else {
            IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
        }
    }

}