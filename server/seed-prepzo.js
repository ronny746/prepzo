require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const MONGO_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/lms-platform';

const branchSchema = new mongoose.Schema({
  name: { type: String, required: true },
  code: { type: String },
  address: { type: String },
  contactEmail: { type: String },
  contactPhone: { type: String }
});

const instituteSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  domain: { type: String, unique: true, sparse: true },
  subdomain: { type: String, unique: true, required: true },
  logoUrl: { type: String },
  planType: { type: String, enum: ['free', 'basic', 'premium', 'enterprise'], default: 'enterprise' },
  contactEmail: { type: String, required: true },
  contactPhone: { type: String },
  address: { type: String },
  branches: [branchSchema],
  settings: {
    features: {
      liveClasses: { type: Boolean, default: true },
      paymentGateway: { type: Boolean, default: true },
      smsNotifications: { type: Boolean, default: true }
    },
    branding: {
      primaryColor: { type: String, default: '#005C42' },
      secondaryColor: { type: String, default: '#C99A2E' }
    }
  },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

const userSchema = new mongoose.Schema({
  instituteId: { type: mongoose.Schema.Types.ObjectId, ref: 'Institute' },
  firstName: { type: String, required: true },
  lastName: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true, select: false },
  phone: { type: String },
  role: { type: String, required: true },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

const courseSchema = new mongoose.Schema({
  instituteId: { type: mongoose.Schema.Types.ObjectId, required: true },
  name: { type: String, required: true },
  tag: { type: String },
  description: { type: String },
  fee: { type: Number },
  duration: { type: String },
  subtitle: { type: String },
  features: [{ type: String }],
  bestFor: [{ type: String }],
  color: { type: String },
  badge: { type: String },
  popular: { type: Boolean, default: false },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });
courseSchema.index({ instituteId: 1, name: 1 }, { unique: true });

const batchSchema = new mongoose.Schema({
  instituteId: { type: mongoose.Schema.Types.ObjectId, required: true },
  courseId: { type: mongoose.Schema.Types.ObjectId },
  name: String,
  section: String,
  type: { type: String, default: 'offline' },
  students: [],
  batchTeacherId: mongoose.Schema.Types.ObjectId,
  isActive: { type: Boolean, default: true }
}, { timestamps: true });
batchSchema.index({ instituteId: 1, name: 1, section: 1 }, { unique: true });

const otpSchema = new mongoose.Schema({
  phone: { type: String },
  email: { type: String },
  otp: { type: String, required: true },
  createdAt: { type: Date, default: Date.now, expires: 300 }
});

const Institute = mongoose.models.Institute || mongoose.model('Institute', instituteSchema);
const User = mongoose.models.User || mongoose.model('User', userSchema);
const Course = mongoose.models.Course || mongoose.model('Course', courseSchema);
const Batch = mongoose.models.Batch || mongoose.model('Batch', batchSchema);
const Otp = mongoose.models.Otp || mongoose.model('Otp', otpSchema);

const COURSES = [
  {
    name: 'Prepzo Prime',
    subtitle: 'Complete NEET Preparation Program',
    fee: 9999,
    tag: 'NEET 2027',
    description: 'The ultimate online course for NEET aspirants. Daily live classes, comprehensive test series, and dedicated doubt support.',
    duration: '12 Months',
    color: '#005C42',
    popular: true,
    badge: 'BEST VALUE',
    features: [
      'Daily LIVE Interactive Classes',
      'High Quality Class Notes (PDF)',
      'Complete NEET PYQ Practice Sheets',
      'Full Access to NEET Yoddha Test Series (CBT)',
      'Subject-wise Daily Practice Papers (DPPs)',
      '24×7 One-to-One Doubt Support'
    ],
    bestFor: ['First-time aspirants', 'Class XI & XII students', 'Droppers'],
    batches: [
      { name: 'Morning Prime', section: 'M1', type: 'hybrid' },
      { name: 'Evening Prime', section: 'E1', type: 'online' }
    ]
  },
  {
    name: 'NEET Yodha Test Series',
    subtitle: 'Practice Like the Real NEET Exam',
    fee: 6999,
    tag: 'NEET 2027',
    description: 'Comprehensive test series for NEET aspirants who want to polish their preparation and track their rank.',
    duration: '8 Months',
    color: '#e8470a',
    popular: false,
    badge: '',
    features: [
      'Computer-Based Tests (CBT)',
      'NEET Pattern Tests',
      'Minor & Major, Chapter-wise Tests',
      'Rank Prediction'
    ],
    bestFor: ['Coaching students', 'Self-study aspirants', 'Revision phase'],
    batches: [
      { name: 'Test Batch', section: 'T1', type: 'online' }
    ]
  },
  {
    name: 'Prepzo NEO',
    subtitle: 'Learn with Expert Faculty',
    fee: 4999,
    tag: 'NEET 2027',
    description: 'Focused learning program with live classes, study material, and doubt clearing sessions.',
    duration: '6 Months',
    color: '#7b3fa0',
    popular: false,
    badge: '',
    features: [
      'Daily LIVE Classes',
      'Concept Building from Basics',
      'Class Notes PDF',
      'Subject-wise DPPs'
    ],
    bestFor: ['Conceptual learners', 'Freshers', 'Repeaters wanting clarity'],
    batches: [
      { name: 'NEO Morning', section: 'N1', type: 'hybrid' }
    ]
  }
];

async function runSeed() {
  console.log('Connecting to MongoDB at:', MONGO_URI.replace(/:([^:@]+)@/, ':****@'));
  await mongoose.connect(MONGO_URI);
  console.log('Connected to MongoDB successfully.');

  // 1. Create or Find Institute
  let institute = await Institute.findOne({ subdomain: 'prepzo' });
  if (!institute) {
    institute = await Institute.create({
      name: 'Prepzo',
      subdomain: 'prepzo',
      domain: 'theprepzo.com',
      logoUrl: '/prepzo-logo.png',
      planType: 'enterprise',
      contactEmail: 'prepzo333@gmail.com',
      contactPhone: '+91-9876543210',
      address: 'Prepzo Headquarters',
      branches: [
        {
          name: 'Main Campus',
          code: 'HQ',
          address: 'Prepzo Headquarters',
          contactEmail: 'prepzo333@gmail.com',
          contactPhone: '+91-9876543210'
        }
      ],
      settings: {
        features: { liveClasses: true, paymentGateway: true, smsNotifications: true },
        branding: { primaryColor: '#005C42', secondaryColor: '#C99A2E' }
      },
      isActive: true
    });
    console.log('🏫 Institute created: Prepzo (ID:', institute._id.toString(), ')');
  } else {
    institute.contactEmail = 'prepzo333@gmail.com';
    institute.domain = 'theprepzo.com';
    institute.name = 'Prepzo';
    await institute.save();
    console.log('🏫 Institute updated: Prepzo (ID:', institute._id.toString(), ')');
  }

  // 2. Create or update the institute admin user: prepzo333@gmail.com
  const adminEmail = 'prepzo333@gmail.com';
  let admin = await User.findOne({ email: adminEmail });
  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash('Admin@123', salt);

  if (!admin) {
    admin = await User.create({
      instituteId: institute._id,
      firstName: 'Prepzo',
      lastName: 'Admin',
      email: adminEmail,
      password: hashedPassword,
      phone: '9876543210',
      role: 'admin',
      isActive: true
    });
    console.log('👤 Admin created:', adminEmail);
  } else {
    admin.instituteId = institute._id;
    admin.role = 'admin';
    admin.password = hashedPassword;
    admin.isActive = true;
    await admin.save();
    console.log('👤 Admin updated and linked to institute:', adminEmail);
  }

  // 3. Seed Courses & Batches
  for (const courseData of COURSES) {
    const { batches, ...cData } = courseData;
    let course = await Course.findOne({ instituteId: institute._id, name: cData.name });
    if (!course) {
      course = await Course.create({ ...cData, instituteId: institute._id });
      console.log('🎓 Course created:', cData.name);
    } else {
      console.log('🎓 Course already exists:', cData.name);
    }

    for (const bData of batches) {
      const existingBatch = await Batch.findOne({ instituteId: institute._id, courseId: course._id, name: bData.name, section: bData.section });
      if (!existingBatch) {
        await Batch.create({ ...bData, instituteId: institute._id, courseId: course._id });
        console.log('  ↳ 📚 Batch created:', bData.name);
      } else {
        console.log('  ↳ 📚 Batch already exists:', bData.name);
      }
    }
  }

  // 4. Seed active OTP record for prepzo333@gmail.com
  await Otp.deleteMany({ email: adminEmail.toLowerCase() });
  await Otp.create({
    email: adminEmail.toLowerCase(),
    phone: '9876543210',
    otp: '123456'
  });
  console.log('🔑 OTP record created in DB: 123456 for', adminEmail);

  console.log('\n=============================================');
  console.log('SUCCESS: Coaching institute & admin ready!');
  console.log('Institute Name : Prepzo');
  console.log('Institute ID   :', institute._id.toString());
  console.log('Admin ID       :', admin._id.toString());
  console.log('Admin Email    :', adminEmail);
  console.log('Default Pass   : Admin@123');
  console.log('OTP (Static)   : 123456');
  console.log('Admin Login URL: http://localhost:3000/prepzo-admin');
  console.log('=============================================\n');

  await mongoose.disconnect();
  process.exit(0);
}

runSeed().catch(err => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
