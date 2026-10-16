// ============================================================
// RWJO LIVE DASHBOARD
// ============================================================
// Connects the frontend to the deployed RWJO contracts
// running on local Anvil.
// ============================================================


// ============================================================
// DEPLOYED CONTRACT ADDRESSES
// ============================================================

const DISPUTE =
    "0x67d269191c92acf3cd7723f116c85e6e9bf55933";

const REGISTRY = "0xc5a5c42992decbae36851359345fe25997f5c42d";


// ============================================================
// ANVIL NETWORK
// ============================================================

const RPC_URL =
    "http://127.0.0.1:8545";

const ANVIL_CHAIN_ID =
    "0x7A69"; // 31337


// ============================================================
// GLOBALS
// ============================================================

let provider = null;

// Browser provider used for MetaMask transactions
let signer = null;

// Separate read-only provider.
// IMPORTANT: This always talks directly to Anvil.
let readProvider = null;

let disputeContract = null;
let registryContract = null;

let connectedAddress = null;


// ============================================================
// DISPUTE MODULE ABI
// ============================================================

const disputeABI = [

    "function initiateDispute(uint256 candidatePrice,uint256 basePrice,bool honeypot,uint256 honeypotTarget) external returns (uint256)",

    "function commitVote(uint256 roundId,bytes32 hashCommit) external",

    "function revealVote(uint256 roundId,uint256 price,uint256 predictedMean,bytes32 salt) external",

    "function settleDispute(uint256 roundId) external",

    "function read() external view returns (uint256 price,bool disputed)",

    "function latestResolvedPrice() external view returns (uint256)",

    "function isDisputed() external view returns (bool)",

    "function disputeCounter() external view returns (uint256)",

    "function disputes(uint256) external view returns (uint256 candidatePrice,uint256 referenceBasePrice,uint256 commitDeadline,uint256 revealDeadline,bool isHoneypot,uint256 honeypotTarget,bool settled,uint256 resolvedPrice)"

];


// ============================================================
// JUROR REGISTRY ABI
// ============================================================

const registryABI = [

    "function jurors(address) external view returns (uint256 bond,uint256 reputation,uint256 vestedReputation,uint256 lastRoundActive,bool isRegistered)",

    "function getEffectiveWeight(address) external view returns (uint256)"

];


// ============================================================
// INITIALIZE READ PROVIDER
// ============================================================

function initializeReadProvider() {

    if (!readProvider) {

        readProvider =
            new ethers.JsonRpcProvider(
                RPC_URL
            );

    }

    return readProvider;
}


// ============================================================
// ENSURE ANVIL NETWORK
// ============================================================

async function ensureAnvilNetwork() {

    if (!window.ethereum) {

        throw new Error(
            "MetaMask is not installed."
        );

    }

    const currentChainId =
        await window.ethereum.request({
            method: "eth_chainId"
        });


    // Already on Anvil
    if (
        currentChainId.toLowerCase() ===
        ANVIL_CHAIN_ID.toLowerCase()
    ) {

        return true;

    }


    setMessage(
        "Switching MetaMask to Anvil Local..."
    );


    try {

        // Try switching to existing Anvil network
        await window.ethereum.request({

            method:
                "wallet_switchEthereumChain",

            params: [
                {
                    chainId:
                        ANVIL_CHAIN_ID
                }
            ]

        });

    }

    catch (error) {

        // Error 4902 = network not added
        if (error.code === 4902) {

            await window.ethereum.request({

                method:
                    "wallet_addEthereumChain",

                params: [

                    {

                        chainId:
                            ANVIL_CHAIN_ID,

                        chainName:
                            "Anvil Local",

                        nativeCurrency:
                        {
                            name:
                                "Ether",

                            symbol:
                                "ETH",

                            decimals:
                                18
                        },

                        rpcUrls:
                        [
                            RPC_URL
                        ]

                    }

                ]

            });

        }

        else {

            throw error;

        }

    }


    // Verify that MetaMask actually switched
    const finalChainId =
        await window.ethereum.request({
            method: "eth_chainId"
        });


    if (
        finalChainId.toLowerCase() !==
        ANVIL_CHAIN_ID.toLowerCase()
    ) {

        throw new Error(
            "MetaMask is not connected to Anvil Local."
        );

    }


    return true;
}


// ============================================================
// CONNECT WALLET
// ============================================================

async function connect() {

    try {

        if (!window.ethereum) {

            setMessage(
                "MetaMask was not detected. Install MetaMask first."
            );

            return;

        }


        // --------------------------------------------------------
        // FIRST: switch MetaMask to Anvil
        // --------------------------------------------------------

        await ensureAnvilNetwork();


        // --------------------------------------------------------
        // Create BrowserProvider
        // --------------------------------------------------------

        provider =
            new ethers.BrowserProvider(
                window.ethereum
            );


        // --------------------------------------------------------
        // Request wallet
        // --------------------------------------------------------

        await provider.send(
            "eth_requestAccounts",
            []
        );


        // --------------------------------------------------------
        // Get signer
        // --------------------------------------------------------

        signer =
            await provider.getSigner();


        connectedAddress =
            await signer.getAddress();


        // --------------------------------------------------------
        // Verify network
        // --------------------------------------------------------

        const network =
            await provider.getNetwork();


        console.log(
            "Connected chain:",
            network.chainId.toString()
        );


        if (
            network.chainId !== 31337n
        ) {

            throw new Error(
                "Wrong network. Please connect MetaMask to Anvil Local."
            );

        }


        // --------------------------------------------------------
        // Create transaction contracts
        // --------------------------------------------------------

        disputeContract =
            new ethers.Contract(
                DISPUTE,
                disputeABI,
                signer
            );


        registryContract =
            new ethers.Contract(
                REGISTRY,
                registryABI,
                signer
            );


        // --------------------------------------------------------
        // Update connect button
        // --------------------------------------------------------

        const connectButton =
            document.querySelector(
                ".connect-btn"
            );


        if (connectButton) {

            connectButton.innerText =
                connectedAddress.slice(0, 6) +
                "..." +
                connectedAddress.slice(-4);

        }


        // --------------------------------------------------------
        // Update status
        // --------------------------------------------------------

        const status =
            document.querySelector(
                ".status"
            );


        if (status) {

            status.innerText =
                "● ANVIL CONNECTED";

            status.style.color =
                "#4ade80";

        }


        setMessage(

            "✓ Wallet connected to Anvil: " +
            connectedAddress.slice(0, 6) +
            "..." +
            connectedAddress.slice(-4)

        );


        await refreshDashboard();

    }


    catch (error) {

        console.error(
            "Wallet connection error:",
            error
        );


        setMessage(
            "Wallet connection failed: " +
            getErrorMessage(error)
        );

    }

}


// ============================================================
// INITIATE DISPUTE
// ============================================================

async function initiateDispute() {

    try {

        await ensureConnected();

        await ensureAnvilNetwork();


        setMessage(
            "Creating dispute on-chain..."
        );


        // --------------------------------------------------------
        // Demo values
        //
        // candidatePrice = 1000
        // basePrice      = 1000
        // honeypot       = false
        // target         = 1000
        // --------------------------------------------------------

        const tx =
            await disputeContract.initiateDispute(

                1000,

                1000,

                false,

                1000

            );


        setMessage(
            "Transaction submitted. Waiting for confirmation..."
        );


        await tx.wait();


        setMessage(
            "✓ Dispute successfully created on-chain."
        );


        await refreshDashboard();

    }


    catch (error) {

        console.error(
            "Initiate dispute error:",
            error
        );


        setMessage(
            "Dispute failed: " +
            getErrorMessage(error)
        );

    }

}


// ============================================================
// COMMIT VOTE
// ============================================================

async function commitVote() {

    try {

        await ensureConnected();

        await ensureAnvilNetwork();


        // --------------------------------------------------------
        // Get latest dispute round
        // --------------------------------------------------------

        const roundId =
            await disputeContract.disputeCounter();


        if (roundId === 0n) {

            setMessage(
                "No dispute round exists yet."
            );

            return;

        }


        // --------------------------------------------------------
        // DEMO VOTE
        // --------------------------------------------------------

        const price =
            1000;

        const predictedMean =
            1000;


        // Fixed demo salt
        const salt =
            ethers.keccak256(

                ethers.toUtf8Bytes(
                    "RWJO-DEMO-SALT-1"
                )

            );


        // --------------------------------------------------------
        // Same calculation as Solidity:
        //
        // keccak256(
        //     abi.encodePacked(
        //         price,
        //         predictedMean,
        //         salt
        //     )
        // )
        // --------------------------------------------------------

        const commitment =
            ethers.solidityPackedKeccak256(

                [
                    "uint256",
                    "uint256",
                    "bytes32"
                ],

                [
                    price,
                    predictedMean,
                    salt
                ]

            );


        console.log(
            "Round:",
            roundId.toString()
        );

        console.log(
            "Price:",
            price
        );

        console.log(
            "Predicted:",
            predictedMean
        );

        console.log(
            "Salt:",
            salt
        );

        console.log(
            "Commitment:",
            commitment
        );


        setMessage(
            "Submitting vote commitment..."
        );


        const tx =
            await disputeContract.commitVote(

                roundId,

                commitment

            );


        setMessage(
            "Commit submitted. Waiting for confirmation..."
        );


        await tx.wait();


        // --------------------------------------------------------
        // Save reveal information locally
        // --------------------------------------------------------

        localStorage.setItem(
            "rwjo_round",
            roundId.toString()
        );


        localStorage.setItem(
            "rwjo_price",
            price.toString()
        );


        localStorage.setItem(
            "rwjo_predicted",
            predictedMean.toString()
        );


        localStorage.setItem(
            "rwjo_salt",
            salt
        );


        setMessage(

            "✓ Vote committed on-chain for Round #" +
            roundId.toString()

        );


        await refreshDashboard();

    }


    catch (error) {

        console.error(
            "Commit error:",
            error
        );


        setMessage(
            "Commit failed: " +
            getErrorMessage(error)
        );

    }

}


// ============================================================
// REVEAL VOTE
// ============================================================

async function revealVote() {

    try {

        await ensureConnected();

        await ensureAnvilNetwork();


        // --------------------------------------------------------
        // Recover exact commit values
        // --------------------------------------------------------

        const storedRound =
            localStorage.getItem(
                "rwjo_round"
            );


        const storedPrice =
            localStorage.getItem(
                "rwjo_price"
            );


        const storedPredicted =
            localStorage.getItem(
                "rwjo_predicted"
            );


        const storedSalt =
            localStorage.getItem(
                "rwjo_salt"
            );


        if (

            !storedRound ||
            !storedPrice ||
            !storedPredicted ||
            !storedSalt

        ) {

            setMessage(
                "No local commitment found. Click Commit Vote first."
            );

            return;

        }


        const roundId =
            BigInt(storedRound);


        const price =
            BigInt(storedPrice);


        const predictedMean =
            BigInt(storedPredicted);


        const salt =
            storedSalt;


        setMessage(
            "Revealing vote on-chain..."
        );


        const tx =
            await disputeContract.revealVote(

                roundId,

                price,

                predictedMean,

                salt

            );


        setMessage(
            "Reveal submitted. Waiting for confirmation..."
        );


        await tx.wait();


        setMessage(
            "✓ Vote revealed successfully."
        );


        await refreshDashboard();

    }


    catch (error) {

        console.error(
            "Reveal error:",
            error
        );


        setMessage(
            "Reveal failed: " +
            getErrorMessage(error)
        );

    }

}


// ============================================================
// RESOLVE DISPUTE
// ============================================================

async function resolveDispute() {

    try {

        await ensureConnected();

        await ensureAnvilNetwork();


        // --------------------------------------------------------
        // Get latest round
        // --------------------------------------------------------

        const roundId =
            await disputeContract.disputeCounter();


        if (roundId === 0n) {

            setMessage(
                "No dispute exists."
            );

            return;

        }


        // --------------------------------------------------------
        // Read round information
        // --------------------------------------------------------

        const round =
            await disputeContract.disputes(
                roundId
            );


        const settled =
            round[6];


        if (settled) {

            setMessage(
                "This dispute has already been settled."
            );

            await refreshDashboard();

            return;

        }


        setMessage(
            "Attempting to resolve dispute..."
        );


        // --------------------------------------------------------
        // Settle on-chain
        // --------------------------------------------------------

        const tx =
            await disputeContract.settleDispute(
                roundId
            );


        setMessage(
            "Resolution submitted. Waiting for confirmation..."
        );


        await tx.wait();


        setMessage(
            "✓ Dispute resolved on-chain."
        );


        await refreshDashboard();

    }


    catch (error) {

        console.error(
            "Resolve error:",
            error
        );


        setMessage(
            "Resolution failed: " +
            getErrorMessage(error)
        );

    }

}


// ============================================================
// REFRESH DASHBOARD
// ============================================================

async function refreshDashboard() {

    try {

        // IMPORTANT:
        // Always use Anvil directly for dashboard reads.
        const readProvider =
            initializeReadProvider();


        const readDispute =
            new ethers.Contract(

                DISPUTE,

                disputeABI,

                readProvider

            );


        // --------------------------------------------------------
        // Read oracle
        // --------------------------------------------------------

        const result =
            await readDispute.read();


        const price =
            result[0];


        const disputed =
            result[1];


        // --------------------------------------------------------
        // Read dispute count
        // --------------------------------------------------------

        const counter =
            await readDispute.disputeCounter();


        // --------------------------------------------------------
        // Current price
        // --------------------------------------------------------

        const currentPrice =
            document.getElementById(
                "currentPrice"
            );


        if (currentPrice) {

            currentPrice.innerText =
                "$" +
                Number(price).toLocaleString();

        }


        // --------------------------------------------------------
        // Resolved price
        // --------------------------------------------------------

        const resolvedPrice =
            document.getElementById(
                "resolvedPrice"
            );


        if (resolvedPrice) {

            resolvedPrice.innerText =
                "$" +
                Number(price).toLocaleString();

        }


        // --------------------------------------------------------
        // Oracle status
        // --------------------------------------------------------

        const oracleStatus =
            document.getElementById(
                "oracleStatus"
            );


        if (oracleStatus) {

            if (disputed) {

                oracleStatus.innerText =
                    "DISPUTED";

                oracleStatus.style.color =
                    "#facc15";

            }

            else {

                oracleStatus.innerText =
                    "RESOLVED";

                oracleStatus.style.color =
                    "#4ade80";

            }

        }


        // --------------------------------------------------------
        // Dispute counter
        // --------------------------------------------------------

        const disputeCount =
            document.getElementById(
                "disputeCount"
            );


        if (disputeCount) {

            disputeCount.innerText =
                counter.toString();

        }


        // --------------------------------------------------------
        // Current round
        // --------------------------------------------------------

        if (counter > 0n) {

            const round =
                await readDispute.disputes(
                    counter
                );


            const candidate =
                round[0];


            const reference =
                round[1];


            const settled =
                round[6];


            const storedResolved =
                round[7];


            // ----------------------------------------------------
            // Candidate price
            // ----------------------------------------------------

            const candidateElement =
                document.getElementById(
                    "candidatePrice"
                );


            if (candidateElement) {

                candidateElement.innerText =
                    "$" +
                    Number(
                        candidate
                    ).toLocaleString();

            }


            // ----------------------------------------------------
            // Reference price
            // ----------------------------------------------------

            const referenceElement =
                document.getElementById(
                    "referencePrice"
                );


            if (referenceElement) {

                referenceElement.innerText =
                    "$" +
                    Number(
                        reference
                    ).toLocaleString();

            }


            // ----------------------------------------------------
            // Resolved price
            // ----------------------------------------------------

            if (settled) {

                const resolvedElement =
                    document.getElementById(
                        "resolvedPrice"
                    );


                if (resolvedElement) {

                    resolvedElement.innerText =
                        "$" +
                        Number(
                            storedResolved
                        ).toLocaleString();

                }

            }

        }

    }


    catch (error) {

        console.error(
            "Dashboard refresh error:",
            error
        );

    }

}


// ============================================================
// CHECK WALLET / CONTRACT CONNECTION
// ============================================================

async function ensureConnected() {

    if (!window.ethereum) {

        throw new Error(
            "MetaMask is not installed."
        );

    }


    // Always make sure MetaMask is on Anvil
    await ensureAnvilNetwork();


    // If not connected yet, connect
    if (
        !signer ||
        !disputeContract
    ) {

        await connect();

    }


    if (
        !signer ||
        !disputeContract
    ) {

        throw new Error(
            "Wallet is not connected."
        );

    }

}


// ============================================================
// DISPLAY MESSAGE
// ============================================================

function setMessage(message) {

    const element =
        document.getElementById(
            "message"
        );


    if (element) {

        element.innerText =
            message;

    }

}


// ============================================================
// ERROR HANDLER
// ============================================================

function getErrorMessage(error) {

    if (!error) {

        return "Unknown error";

    }


    // User rejected MetaMask transaction
    if (
        error.code === 4001 ||
        error.code === "ACTION_REJECTED"
    ) {

        return "Transaction rejected in MetaMask.";

    }


    if (error.shortMessage) {

        return error.shortMessage;

    }


    if (
        error.info &&
        error.info.error &&
        error.info.error.message
    ) {

        return error.info.error.message;

    }


    if (error.reason) {

        return error.reason;

    }


    if (error.message) {

        return error.message
            .replace(
                /^Error:\s*/,
                ""
            )
            .slice(
                0,
                300
            );

    }


    return "Transaction failed";

}


// ============================================================
// METAMASK ACCOUNT / NETWORK CHANGES
// ============================================================

if (window.ethereum) {

    window.ethereum.on(
        "accountsChanged",
        async function (accounts) {

            // Reset signer/contracts
            signer = null;
            disputeContract = null;
            registryContract = null;
            connectedAddress = null;


            if (
                accounts &&
                accounts.length > 0
            ) {

                try {

                    await connect();

                }

                catch (error) {

                    console.error(
                        error
                    );

                }

            }

        }
    );


    window.ethereum.on(
        "chainChanged",
        async function () {

            // Reload so ethers uses the new network cleanly
            window.location.reload();

        }
    );

}


// ============================================================
// AUTO REFRESH
// ============================================================

setInterval(

    refreshDashboard,

    3000

);


// ============================================================
// INITIAL PAGE LOAD
// ============================================================

window.addEventListener(

    "load",

    async function () {

        try {

            // Initialize direct Anvil reader
            initializeReadProvider();


            await refreshDashboard();

        }


        catch (error) {

            console.error(

                "Initial dashboard load failed:",

                error

            );

        }

    }

);