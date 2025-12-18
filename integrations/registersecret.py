from circle.web3 import utils
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()



api_key = os.getenv('API_KEY')
entity_secret = os.getenv('ENTITY_SECRET')

result = utils.register_entity_secret_ciphertext(
    api_key=api_key,
    entity_secret=entity_secret,
    recoveryFileDownloadPath='')
print(result)