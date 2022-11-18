// SPDX-License-Identifier: AGPLv3                                                                                                                   
pragma solidity 0.8.17;

// exclude EccZapper from fees on ECC
// take 50% EMPIRE, 50% ECC to make LP
// send LP back to users

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);

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
    IEmpireRouter private router;
    IERC20 public ecc;
    IERC20 public empire;

    event eccEmpireLiquidityAdded(uint lpTokensCreated, uint eccAdded, uint empireAdded);
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

    constructor (address eRouter) {
        // router = IEmpireRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        router = IEmpireRouter(eRouter);
        ecc = IERC20(0xfE06CCfAc526d141131c041fb443E5678D011c56);
        empire = IERC20(0x2a114dBd8C97dD3d369963790FBdf0eb74AFa95F);
    }

    receive() external payable { }

    function zapEthForEccEmpire() external payable {
        (bool sent,) = address(this).call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        uint halfETH = address(this).balance/2;
        address[] memory path = new address[](2);

        // Swap 50% ETH for ECC
        path[0] = address(router.WETH());
        path[1] = address(ecc);
        uint[] memory amounts1 = router.swapExactETHForTokens{value: halfETH}(
            0,
            path,
            address(this),
            block.timestamp + 10
        );
        uint eccAmount = amounts1[1];

        // Swap 50% ETH for EMPIRE
        path[0] = address(router.WETH());
        path[1] = address(empire);
        uint[] memory amounts2 = router.swapExactETHForTokens{value: halfETH}(
            0,
            path,
            address(this),
            block.timestamp + 10
        );
        uint empireAmount = amounts2[1];

        // Create & Send LP
        ecc.approve(address(router), eccAmount);
        empire.approve(address(router), empireAmount);
        (uint _eccAdded, uint _empireAdded, uint _lpTokensCreated) = router.addLiquidity(
            address(ecc),
            address(empire),
            eccAmount,
            empireAmount,
            0,
            0,
            msg.sender,
            block.timestamp + 10
        );
        emit eccEmpireLiquidityAdded(_lpTokensCreated, _eccAdded, _empireAdded);
    }

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
            uint _lpTokensCreated,
            address tokenA,
            address tokenB,
            uint _tokenAadded,
            uint _tokenBadded
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
        empire.approve(address(router), empireAmount);
        (uint _tokenAmount, uint _ETHamount, uint _lpTokensCreated) = router.addLiquidity
            {value: halfETH}(
            token,
            tokenAmount,
            0,
            0,
            msg.sender,
            block.timestamp + 10
        );

        emit ETHLiquidityAdded(
            uint _lpTokensCreated,
            address token,
            uint _tokenAamount,
            uint _ETHamount
        );
    }

}