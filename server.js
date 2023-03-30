const Web3 = require('web3');
const express = require('express');
const cors = require('cors');
const app = express();
app.use(express.json());
app.use(cors());
app.use(express.urlencoded({ extended: true }));
const port = 3000;

const Reputation = require('./build/contracts/Reputation.json');

const web3 = new Web3(new Web3("http://localhost:7545"));

web3.eth.net.isListening()
  .then(() => console.log('Connected to Ganache!'))
  .catch((err) => console.error(err));

const contractAddress = "0x56f8195D5d8F271D3e9ED045E99A7d734608893D"; // replace with your contract address
const contract = new web3.eth.Contract(Reputation.abi, contractAddress);

// add an authority node to the contract
async function addAuthorityNode(address) {
  const accounts = await web3.eth.getAccounts();
  console.log(accounts)
  return accounts;
  //const result = await contract.methods.addAuthorityNode(address).send({ from: accounts[0] });
  //return result;
}

// define the endpoint to add an authority node
app.post('/add-authority-node', async (req, res) => {
  console.log(req.body)
  const address = req.body.address;
  try {
    const result = await addAuthorityNode(address);
    res.status(200).send(result);
  } catch (error) {
    console.error(error);
    res.status(500).send(error);
  }
});

// define the endpoint to add an authority node
app.get('/', async (req, res) => {
  res.status(200).send('Hiiiii!!!!!!!!');
});

app.listen(port, () => console.log(`Example app listening at http://localhost:${port}`));

