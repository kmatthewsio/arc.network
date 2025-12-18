import json
import os
import uuid
from pathlib import Path

from circle.web3 import utils
from circle.web3 import developer_controlled_wallets
from circle.web3 import smart_contract_platform

from dotenv import load_dotenv
import os

# Load .env file
load_dotenv()

ARTIFACT_PATH = Path(r"C:\ark.network\hello-arc\out\GuestBook.sol\GuestBook.json")
CHAIN = "ARC-TESTNET"  # Arc public testnet


def load_abi_and_bytecode(artifact_path: Path):
    if not artifact_path.exists():
        raise FileNotFoundError(
            f"Artifact not found: {artifact_path}\n"
            "Did you run `forge build`?"
        )

    artifact = json.loads(artifact_path.read_text(encoding="utf-8"))

    # Foundry artifact shape: ABI in `abi`, bytecode object usually at `bytecode.object`
    abi = artifact.get("abi")
    bytecode_obj = (artifact.get("bytecode") or {}).get("object")

    if not abi or not bytecode_obj:
        raise ValueError(
            "Could not find `abi` or `bytecode.object` in the Foundry artifact."
        )

    # Circle expects abiJson as a JSON-stringified string and bytecode as 0x-prefixed hex
    abi_json_str = json.dumps(abi)
    bytecode_hex = bytecode_obj if bytecode_obj.startswith("0x") else f"0x{bytecode_obj}"

    return abi_json_str, bytecode_hex


def init_clients():
    api_key = "TEST_API_KEY:c9ad7682997f89121f570a2e75c3431b:69130b1f648bcc5852678a592c9fd71f" #os.environ.get("CIRCLE_API_KEY")
    entity_secret = "9ac357b8d740882d40017906388811fd9e99bc2a8f19124a9cea775e21dec023" #os.environ.get("CIRCLE_ENTITY_SECRET")
    if not api_key or not entity_secret:
        raise EnvironmentError("Set CIRCLE_API_KEY and CIRCLE_ENTITY_SECRET in your environment.")

    wallets_client = utils.init_developer_controlled_wallets_client(
        api_key=api_key,
        entity_secret=entity_secret,
    )
    contracts_client = utils.init_smart_contract_platform_client(
        api_key=api_key,
        entity_secret=entity_secret,
    )
    return wallets_client, contracts_client


def create_wallet_on_arc(client):
    wallet_sets_api = developer_controlled_wallets.WalletSetsApi(client)
    wallets_api = developer_controlled_wallets.WalletsApi(client)

    # 1) Create wallet set
    ws_req = developer_controlled_wallets.CreateWalletSetRequest.from_dict({
        "name": f"Arc WalletSet {uuid.uuid4().hex[:8]}"
    })
    ws_resp = wallet_sets_api.create_wallet_set(ws_req)

    # WalletSet id is wrapped under actual_instance in the Python SDK
    wallet_set_id = ws_resp.data.wallet_set.actual_instance.id

    # 2) Create wallet(s) in that set (EOA on Arc Testnet)
    w_req = developer_controlled_wallets.CreateWalletRequest.from_dict({
        "idempotencyKey": str(uuid.uuid4()),
        "blockchains": [CHAIN],
        "walletSetId": wallet_set_id,
        "accountType": "EOA",
        "count": 1
    })
    
    w_resp = wallets_api.create_wallet(w_req)
    wallet_wrapped = w_resp.data.wallets[0]
    wallet = getattr(wallet_wrapped, "actual_instance", wallet_wrapped)  # Fixed: underscore instead of space

    return wallet.id, wallet.address, wallet_set_id


def deploy_contract(contracts_client, wallet_id: str, abi_json: str, bytecode: str):
    deploy_api = smart_contract_platform.DeployImportApi(contracts_client)

    # Use the correct request class
    req = smart_contract_platform.ContractDeploymentRequest.from_dict({
        "idempotencyKey": str(uuid.uuid4()),
        "name": "GuestBook",
        "description": "",
        "walletId": wallet_id,
        "blockchain": CHAIN,
        "abiJson": abi_json,
        "bytecode": bytecode,
        "feeLevel": "MEDIUM",
    })
    
    resp = deploy_api.deploy_contract(req)
        
    return resp.data.contract_id, resp.data.transaction_id


def main():
    abi_json, bytecode = load_abi_and_bytecode(ARTIFACT_PATH)
    wallets_client, contracts_client = init_clients()

    wallet_id, address, wallet_set_id = create_wallet_on_arc(wallets_client)

    print("\n=== Circle Wallet Created (ARC-TESTNET) ===")
    print("walletSetId :", wallet_set_id)
    print("walletId    :", wallet_id)
    print("address     :", address)

    print("\nNEXT STEP: Fund this address with Arc testnet USDC (gas) before deploying.\n")
    input()

    print("\n🚀 Deploying contract...")
    contract_id, tx_id = deploy_contract(contracts_client, wallet_id, abi_json, bytecode)

    print("=== Deploy Submitted ===")
    print("contractId     :", contract_id)
    print("transactionId  :", tx_id)


if __name__ == "__main__":
    main()
