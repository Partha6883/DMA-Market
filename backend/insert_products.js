// insert_products.js
require('dotenv').config();
const mongoose = require("mongoose");

async function connectDB() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("Mongo connected");
  } catch (err) {
    console.error("Mongo connection failed:", err);
    process.exit(1);
  }
}

const produceSchema = new mongoose.Schema({
  name: String,
  price: Number,
  unit: String,
  qty: Number,
  quality: String,
  farmer: String,
  description: String,
  imageUrl: String,
  createdAt: { type: Date, default: Date.now }
});

const Produce = mongoose.model("Produce", produceSchema);

const products = [
  {
    name: "Tomato",
    price: 28,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Fresh tomatoes",
    imageUrl: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTN9-OuOtsl4iecwrOQ4c00iOqngoUdBz1dzQ&s"
  },
  {
    name: "Onion",
    price: 35,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Fresh onions",
    imageUrl: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTWTLSXlSbko9jRKshtH_fTjXukOR83fQkL5A&s"
  },
  {
    name: "Potato",
    price: 25,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Good potatoes",
    imageUrl: "https://m.media-amazon.com/images/I/41QKCkQ2A5L.jpg"
  },
  {
    name: "Carrot",
    price: 40,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Fresh carrots",
    imageUrl: "https://www.lovefoodhatewaste.com/sites/default/files/styles/open_graph_image/public/2022-06/Carrots.jpg.webp?itok=aBgglla9"
  },
  {
    name: "Cabbage",
    price: 20,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Green cabbage",
    imageUrl: "https://4.imimg.com/data4/QW/QS/MY-1875168/green-cabbage-500x500.jpg"
  },
  {
    name: "Beans",
    price: 55,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Fresh beans",
    imageUrl: "https://freshindiaorganics.com/cdn/shop/files/Untitleddesign_26.png?v=1686981937"
  },
  {
    name: "Brinjal",
    price: 35,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Purple brinjal",
    imageUrl: "https://m.media-amazon.com/images/I/51XBbkVrvWL._AC_UF1000,1000_QL80_.jpg"
  },
  {
    name: "Ladies Finger",
    price: 45,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Fresh okra",
    imageUrl: "https://organicmandya.com/cdn/shop/files/Lady_sFinger_Bhendi.jpg?v=1757081503&width=1000"
  },
  {
    name: "Green Chillies",
    price: 70,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Hot chillies",
    imageUrl: "https://www.jiomart.com/images/product/original/590002423/chilli-green-100-g-pack-product-images-o590002423-p611038331-1-202502201628.jpg?im=Resize=(420,420)"
  },
  {
    name: "Coriander",
    price: 15,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Fresh coriander",
    imageUrl: "https://www.allthatgrows.in/cdn/shop/products/Coriander.jpg?v=1598076422"
  },

  // Fruits
  {
    name: "Banana",
    price: 45,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Yelakki banana",
    imageUrl: "https://www.dole.com/sites/default/files/media/2025-01/banana-cavendish_0.png"
  },
  {
    name: "Apple",
    price: 160,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Fresh apples",
    imageUrl: "https://www.collinsdictionary.com/images/full/apple_158989157.jpg"
  },
  {
    name: "Grapes",
    price: 90,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Seedless grapes",
    imageUrl: "https://www.dole.com/sites/default/files/media/2025-01/grapes.png"
  },
  {
    name: "Mango",
    price: 120,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Alphonso mango",
    imageUrl: "https://devgadmango.com/wp-content/uploads/2020/03/banganapalli-mango.png"
  },
  {
    name: "Pomegranate",
    price: 150,
    unit: "kg",
    qty: 100,
    quality: "A",
    farmer: "Karnataka Govt",
    description: "Quality pomegranate",
    imageUrl: "https://m.media-amazon.com/images/I/611a1wD9ZGL._AC_UF894,1000_QL80_.jpg"
  }
];

async function run() {
  await connectDB();
  console.log("Inserting 15 products with images...");

  await Produce.insertMany(products);

  console.log("Insertion complete.");
  mongoose.disconnect();
}

run();
