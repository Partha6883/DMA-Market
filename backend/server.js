// server.js 
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const multer = require('multer');
const path = require('path');
const cors = require('cors');
const morgan = require('morgan');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

const UPLOAD_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || (file.mimetype ? `.${file.mimetype.split('/')[1]}` : '.jpg');
    const name = path.basename(file.originalname, path.extname(file.originalname)).replace(/\s+/g, '_');
    cb(null, `${name}_${Date.now()}${ext}`);
  }
});
const upload = multer({ storage });

//  DB 
async function startDb() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('MongoDB connected');
  } catch (err) {
    console.error('MongoDB connection error:', err);
    process.exit(1);
  }
}
startDb();

// Auth deps 
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';
const JWT_EXPIRES = '7d';

// Models 
const userSchema = new mongoose.Schema({
  name: String,
  email: { type: String, unique: true, sparse: true },
  phone: { type: String, unique: true, sparse: true },
  passwordHash: String,
  role: { type: String, enum: ['buyer','farmer'], default: 'buyer' },
  createdAt: { type: Date, default: Date.now }
});
const User = mongoose.model('User', userSchema);

const produceSchema = new mongoose.Schema({
  farmer: { type: String, default: 'unknown' },
  name: { type: String, required: true },
  description: String,
  qty: Number,
  unit: String,
  price: Number,
  quality: String,
  state: String,
  priceHistory: [
    {
      price: Number,
      state: String,
      ts: { type: Date, default: Date.now }
    }
  ],
  imageUrl: String,
  createdAt: { type: Date, default: Date.now }
});
const Produce = mongoose.model('Produce', produceSchema);

const offerSchema = new mongoose.Schema({
  produceId: String,
  produceName: String,
  farmer: String,
  buyerName: String,
  buyerPhone: String,
  offerPrice: Number,
  message: String,
  status: { type: String, default: "pending" },
  createdAt: { type: Date, default: Date.now }
});
const Offer = mongoose.model('Offer', offerSchema);

//  Helpers 
function genToken(user) {
  return jwt.sign({ id: user._id, role: user.role, name: user.name }, JWT_SECRET, { expiresIn: JWT_EXPIRES });
}

function authMiddleware(req, res, next) {
  try {
    const auth = req.headers.authorization;
    if (!auth) return res.status(401).json({ ok: false, error: 'Authorization required' });
    const parts = auth.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') return res.status(401).json({ ok: false, error: 'Invalid auth header' });
    const token = parts[1];
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (err) {
    return res.status(401).json({ ok: false, error: 'Invalid or expired token' });
  }
}

function requireRole(role) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ ok: false, error: 'Auth required' });
    if (req.user.role !== role) return res.status(403).json({ ok: false, error: 'Forbidden' });
    next();
  };
}

// server 
app.use('/uploads', express.static(UPLOAD_DIR));

//  Routes 
app.get('/', (req, res) => res.json({ ok: true, msg: 'DMA backend running' }));

//  AUTH 
app.post('/auth/register',
  body('password').isLength({ min: 6 }).withMessage('password min 6 chars'),
  body('email').optional().isEmail().withMessage('invalid email'),
  body('phone').optional().isMobilePhone('any'),
  async (req, res) => {
    try {
      const errs = validationResult(req);
      if (!errs.isEmpty()) return res.status(400).json({ ok: false, errors: errs.array() });

      const { name, email, phone, password, role } = req.body;
      if (!email && !phone) return res.status(400).json({ ok: false, error: 'email or phone required' });

      if (email) {
        const ex = await User.findOne({ email }).exec();
        if (ex) return res.status(400).json({ ok: false, error: 'email already registered' });
      }
      if (phone) {
        const ex2 = await User.findOne({ phone }).exec();
        if (ex2) return res.status(400).json({ ok: false, error: 'phone already registered' });
      }

      const hash = await bcrypt.hash(password, 10);
      const user = new User({ name, email, phone, passwordHash: hash, role: role === 'farmer' ? 'farmer' : 'buyer' });
      await user.save();
      const token = genToken(user);
      return res.json({ ok: true, token, user: { id: user._id, name: user.name, role: user.role, email: user.email, phone: user.phone }});
    } catch (err) {
      console.error('Register error:', err);
      return res.status(500).json({ ok: false, error: 'server error' });
    }
  }
);

// alias for compatibility
app.post('/register', (req, res) => {
  req.url = '/auth/register';
  app.handle(req, res);
});

app.post('/auth/login',
  body('password').exists(),
  async (req, res) => {
    try {
      const { email, phone, password } = req.body;
      if (!email && !phone) return res.status(400).json({ ok: false, error: 'email or phone required' });

      const user = await User.findOne(email ? { email } : { phone }).exec();
      if (!user) return res.status(400).json({ ok: false, error: 'user not found' });

      const ok = await bcrypt.compare(password, user.passwordHash || '');
      if (!ok) return res.status(400).json({ ok: false, error: 'invalid credentials' });

      const token = genToken(user);
      return res.json({ ok: true, token, user: { id: user._id, name: user.name, role: user.role, email: user.email, phone: user.phone }});
    } catch (err) {
      console.error('Login error:', err);
      return res.status(500).json({ ok: false, error: 'server error' });
    }
  }
);

// alias
app.post('/login', (req, res) => {
  req.url = '/auth/login';
  app.handle(req, res);
});

// get current user
app.get('/auth/me', authMiddleware, async (req, res) => {
  try {
    const u = await User.findById(req.user.id).select('-passwordHash').exec();
    if (!u) return res.status(404).json({ ok: false, error: 'not found' });
    return res.json({ ok: true, user: u });
  } catch (err) {
    console.error('auth/me error:', err);
    return res.status(500).json({ ok: false, error: 'server error' });
  }
});

//  PRODUCE 
// Create produce (farmer only) — image optional. Farmer is set from token.
app.post('/produce', authMiddleware, upload.single('image'), async (req, res) => {
  try {
    const { name, qty, unit, price, description, quality, state } = req.body;
    if (!name) return res.status(400).json({ ok: false, error: 'name is required' });

    let imageUrl = null;
    if (req.file) {
      const base = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
      imageUrl = `${base}/uploads/${req.file.filename}`;
    }

    const farmerName = req.user && req.user.name ? req.user.name : 'unknown';

    const doc = new Produce({
      farmer: farmerName,
      name,
      qty: qty ? Number(qty) : undefined,
      unit: unit || 'kg',
      price: price ? Number(price) : undefined,
      quality,
      state: state ? state.toString() : undefined,
      priceHistory: price ? [{ price: Number(price), state: state ? state.toString() : '', ts: new Date() }] : [],
      imageUrl
    });

    await doc.save();
    return res.json({ ok: true, data: doc });
  } catch (err) {
    console.error('Produce create error:', err);
    return res.status(500).json({ ok: false, error: 'server error', details: err.message });
  }
});

// List produce, optional filter by state or name
app.get('/produce', async (req, res) => {
  try {
    const q = {};
    if (req.query.state) q.state = { $regex: `^${req.query.state}`, $options: 'i' };
    if (req.query.name) q.name = { $regex: `^${req.query.name}$`, $options: 'i' };

    const items = await Produce.find(q).sort({ createdAt: -1 }).limit(500).exec();
    return res.json({ ok: true, data: items });
  } catch (err) {
    console.error('Produce list error:', err);
    return res.status(500).json({ ok: false, error: 'server error' });
  }
});

// Get single produce
app.get('/produce/:id', async (req, res) => {
  try {
    const p = await Produce.findById(req.params.id).exec();
    if (!p) return res.status(404).json({ ok: false, error: 'not found' });
    return res.json({ ok: true, data: p });
  } catch (err) {
    console.error('Produce get error:', err);
    return res.status(500).json({ ok: false, error: 'server error' });
  }
});

// delete produce (no auth required here in case you want admin delete via other tooling)
app.delete('/produce/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const item = await Produce.findByIdAndDelete(id);
    if (!item) return res.status(404).json({ ok: false, error: 'Not found' });

    if (item.imageUrl) {
      const parts = item.imageUrl.split('/uploads/');
      if (parts.length > 1) {
        const filename = parts[1];
        const filePath = path.join(UPLOAD_DIR, filename);
        fs.unlink(filePath, (err) => {
          if (err) console.warn('Failed to delete file:', filePath, err.message);
          else console.log('Deleted file:', filePath);
        });
      }
    }

    return res.json({ ok: true, msg: 'Deleted' });
  } catch (err) {
    console.error('Delete produce error:', err);
    return res.status(500).json({ ok: false, error: 'Delete failed', details: err.message });
  }
});

// Compare endpoint: group same-name produce by state (avg/min/max + samples)
app.get('/produce/compare', async (req, res) => {
  try {
    const name = (req.query.name || '').toString().trim();
    if (!name) return res.status(400).json({ ok: false, error: 'name query required' });

    const docs = await Produce.find({ name: { $regex: `^${name}$`, $options: 'i' } }).exec();

    const byState = {};
    docs.forEach(d => {
      const st = (d.state || 'unknown').toString();
      byState[st] = byState[st] || { state: st, count: 0, sum: 0, min: null, max: null, samples: [] };
      const p = Number(d.price || 0);
      byState[st].count++;
      byState[st].sum += p;
      byState[st].min = byState[st].min === null ? p : Math.min(byState[st].min, p);
      byState[st].max = byState[st].max === null ? p : Math.max(byState[st].max, p);
      byState[st].samples.push({ farmer: d.farmer, price: p, id: d._id, imageUrl: d.imageUrl, state: st });
    });

    const result = Object.values(byState).map(s => ({
      state: s.state,
      avg: s.count ? (s.sum / s.count) : 0,
      min: s.min,
      max: s.max,
      count: s.count,
      samples: s.samples
    }));

    return res.json({ ok: true, name, result });
  } catch (err) {
    console.error('Compare error', err);
    return res.status(500).json({ ok: false, error: 'server error' });
  }
});

//  OFFERS 
// Create offer (buyer only)
app.post('/offers', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== 'buyer') return res.status(403).json({ ok: false, error: 'Only buyers can make offers' });

    const data = req.body || {};
    data.buyerName = data.buyerName || req.user.name || '';
    data.farmer = data.farmer || data.farmer || '';

    if (!data.produceId || (data.offerPrice === undefined || data.offerPrice === null)) {
      return res.status(400).json({ ok: false, error: 'produceId and offerPrice required' });
    }
    data.offerPrice = Number(data.offerPrice);
    if (Number.isNaN(data.offerPrice)) return res.status(400).json({ ok: false, error: 'Invalid offerPrice' });

    const offer = new Offer(data);
    await offer.save();
    res.json({ ok: true, data: offer });
  } catch (err) {
    console.error("Offer POST error:", err);
    res.status(500).json({ ok: false, error: "server error" });
  }
});

// Get offers: farmer sees their offers; buyer can filter by produceId
app.get('/offers', authMiddleware, async (req, res) => {
  try {
    const farmerQuery = req.query.farmer;
    const filter = {};
    if (farmerQuery) filter.farmer = { $regex: `^${farmerQuery}$`, $options: 'i' };
    else if (req.user.role === 'farmer') filter.farmer = { $regex: `^${req.user.name}$`, $options: 'i' };
    if (req.query.produceId) filter.produceId = req.query.produceId;

    const list = await Offer.find(filter).sort({ createdAt: -1 }).exec();
    res.json({ ok: true, data: list });
  } catch (err) {
    console.error("Offer GET error:", err);
    res.status(500).json({ ok: false, error: "server error" });
  }
});

// Update offer status — farmer only, robust ownership check
app.put('/offers/:id', authMiddleware, requireRole('farmer'), async (req, res) => {
  try {
    const id = req.params.id;
    const status = req.body.status;
    const allowed = ['pending','accepted','rejected'];
    if (!status || !allowed.includes(status)) return res.status(400).json({ ok: false, error: 'Invalid status' });

    const offer = await Offer.findById(id).exec();
    if (!offer) return res.status(404).json({ ok: false, error: 'Offer not found' });

    const loggedFarmerName = (req.user && req.user.name ? req.user.name.toString().trim().toLowerCase() : '');

    let isOwner = false;
    if (offer.farmer && offer.farmer.toString().trim().toLowerCase() === loggedFarmerName) isOwner = true;

    if (!isOwner && offer.produceId) {
      try {
        const produceDoc = await Produce.findById(offer.produceId).exec();
        if (produceDoc && produceDoc.farmer && produceDoc.farmer.toString().trim().toLowerCase() === loggedFarmerName) {
          isOwner = true;
        }
      } catch (e) {}
    }

    if (!isOwner) {
      console.warn('Offer ownership check failed:', {
        offerId: id,
        offerFarmer: offer.farmer,
        offerFarmerId: offer.produceId,
        loggedFarmerId: req.user.id,
        loggedFarmerName
      });
      return res.status(403).json({ ok: false, error: 'Not your offer' });
    }

    offer.status = status;
    await offer.save();
    return res.json({ ok: true, data: offer });
  } catch (err) {
    console.error("Offer PUT error:", err);
    return res.status(500).json({ ok: false, error: "server error" });
  }
});

// -------------- Orders / Checkout --------------
const PORT = process.env.PORT || 3000;

// ------ compare-prices endpoint ------
const KNOWN_STATES = [
  "Andhra Pradesh","Arunachal Pradesh","Assam","Bihar","Chhattisgarh",
  "Goa","Gujarat","Haryana","Himachal Pradesh","Jharkhand",
  "Karnataka","Kerala","Madhya Pradesh","Maharashtra","Manipur",
  "Meghalaya","Mizoram","Nagaland","Odisha","Punjab",
  "Rajasthan","Sikkim","Tamil Nadu","Telangana","Tripura",
  "Uttar Pradesh","Uttarakhand","West Bengal","Delhi","Puducherry"
];

function seededNumberFromString(s, min = 20, max = 100) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < s.length; i++) {
    h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  }
  h = (h >>> 0) / 4294967295;
  return min + Math.floor(h * (max - min + 1));
}

app.get('/compare-prices', async (req, res) => {
  try {
    const produce = (req.query.produce || '').toString().trim();
    if (!produce) return res.status(400).json({ ok: false, error: 'produce query param required' });

    if (process.env.AGMARKNET_URL) {
      try {
        const url = `${process.env.AGMARKNET_URL}?produce=${encodeURIComponent(produce)}`;
        console.log('Compare-prices: fetching from AGMARKNET_URL', url);
        const resp = await fetch(url, { method: 'GET', headers: { 'Accept': 'application/json' } });
        if (resp.ok) {
          const j = await resp.json();
          if (j && Array.isArray(j.data)) {
            const prices = j.data.map(x => ({ state: x.state, price: Number(x.price) || 0 }));
            const pricesOnly = prices.map(p => p.price);
            const min = Math.min(...pricesOnly);
            const max = Math.max(...pricesOnly);
            const avg = Math.round((pricesOnly.reduce((a,b)=>a+b,0)/pricesOnly.length) * 100) / 100;
            return res.json({ ok:true, produce, basePrice: null, data: prices, min, max, avg });
          }
        }
        console.warn('AGMARKNET fetch failed or returned unexpected data, falling back to mock');
      } catch (e) {
        console.warn('AGMARKNET fetch error, falling back to mock', e && e.message ? e.message : e);
      }
    }

    const base = seededNumberFromString(produce, 18, 120);
    const data = KNOWN_STATES.map((st) => {
      const offset = Math.round(((seededNumberFromString(produce + st, -12, 12)) / 10));
      const price = Math.max(1, Math.round((base + offset) * 100) / 100);
      return { state: st, price };
    });

    const pricesOnly = data.map(d => d.price);
    const min = Math.min(...pricesOnly);
    const max = Math.max(...pricesOnly);
    const avg = Math.round((pricesOnly.reduce((a,b)=>a+b,0)/pricesOnly.length) * 100) / 100;

    return res.json({ ok: true, produce, basePrice: base, data, min, max, avg });
  } catch (err) {
    console.error('compare-prices error:', err);
    return res.status(500).json({ ok: false, error: 'server error' });
  }
});

// Final Order schema (for checkout)
// (kept separate from earlier models — single canonical definition retained here)
const orderSchema = new mongoose.Schema({
  buyerId: String,
  buyerName: String,
  buyerPhone: String,
  items: [
    {
      produceId: String,
      produceName: String,
      qty: Number,
      unit: String,
      pricePerUnit: Number,
      farmer: String,
      imageUrl: String
    }
  ],
  total: Number,
  status: { type: String, default: "created" }, // created, paid, shipped, cancelled
  createdAt: { type: Date, default: Date.now }
});
const Order = mongoose.model('Order', orderSchema);

// Checkout: buyer posts cart -> create order
app.post('/checkout', authMiddleware, async (req, res) => {
  try {
    if (req.user.role !== 'buyer') return res.status(403).json({ ok: false, error: 'Only buyers can checkout' });

    const data = req.body || {};
    const items = Array.isArray(data.items) ? data.items : [];
    if (items.length === 0) return res.status(400).json({ ok: false, error: 'Cart is empty' });

    let total = 0;
    const cleaned = items.map(it => {
      const qty = Number(it.qty) || 0;
      const pricePerUnit = Number(it.pricePerUnit) || 0;
      const sub = qty * pricePerUnit;
      total += sub;
      return {
        produceId: it.produceId?.toString?.() || '',
        produceName: it.produceName?.toString?.() || '',
        qty,
        unit: it.unit || 'kg',
        pricePerUnit,
        farmer: it.farmer || '',
        imageUrl: it.imageUrl || ''
      };
    });

    const order = new Order({
      buyerId: req.user.id,
      buyerName: req.user.name || '',
      buyerPhone: data.buyerPhone || '',
      items: cleaned,
      total
    });

    await order.save();

    return res.json({ ok: true, data: order });
  } catch (err) {
    console.error('Checkout error:', err);
    return res.status(500).json({ ok: false, error: 'server error' });
  }
});

// Get buyer or farmer orders
app.get('/orders', authMiddleware, async (req, res) => {
  try {
    const filter = {};
    if (req.user.role === 'buyer') filter.buyerId = req.user.id;
    else if (req.user.role === 'farmer') filter['items.farmer'] = { $regex: `^${req.user.name}$`, $options: 'i' };

    const list = await Order.find(filter).sort({ createdAt: -1 }).exec();
    return res.json({ ok: true, data: list });
  } catch (err) {
    console.error('Orders list error:', err);
    return res.status(500).json({ ok: false, error: 'server error' });
  }
});

app.listen(PORT, '0.0.0.0', () => console.log(`Server started on port ${PORT}`));
