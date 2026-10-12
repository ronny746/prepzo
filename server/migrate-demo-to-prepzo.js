require('dotenv').config();
const mongoose = require('mongoose');

const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lms-platform';

async function migrate() {
  console.log('Connecting to MongoDB cluster...');
  await mongoose.connect(uri);
  console.log('Connected successfully.\n');

  const demoDb = mongoose.connection.client.db('demoappName=Cluster0');
  const prepzoDb = mongoose.connection.client.db('prepzo=Cluster0');

  // Verify institutes
  const prepzoInst = await prepzoDb.collection('institutes').findOne({ subdomain: 'prepzo' });
  if (!prepzoInst) {
    throw new Error('Prepzo institute not found in prepzo=Cluster0!');
  }
  const newInstId = prepzoInst._id;
  const demoInst = await demoDb.collection('institutes').findOne();
  const oldInstId = demoInst ? demoInst._id : new mongoose.Types.ObjectId('6abce156d8206ade5bf59812');

  console.log('Target Prepzo Institute ID:', newInstId.toString());
  console.log('Source Demo Institute ID  :', oldInstId.toString());
  console.log('--------------------------------------------------\n');

  // Helper to remap institute IDs recursively or in top-level fields
  function remapDoc(doc) {
    if (!doc) return doc;
    if (doc.instituteId && (doc.instituteId.toString() === oldInstId.toString())) {
      doc.instituteId = newInstId;
    }
    if (doc.institute && (doc.institute.toString() === oldInstId.toString())) {
      doc.institute = newInstId;
    }
    return doc;
  }

  // 1. Migrate Collections with special handling
  // A. USERS
  console.log('👉 Migrating users...');
  const demoUsers = await demoDb.collection('users').find().toArray();
  let usersMigrated = 0;
  for (const user of demoUsers) {
    // Skip old demo superadmin geniusattechie@gmail.com to protect prepzo333@gmail.com
    if (user.email === 'geniusattechie@gmail.com') {
      console.log('  [Skip] Old demo admin geniusattechie@gmail.com (keeping prepzo333@gmail.com as primary admin)');
      continue;
    }

    // Rohit rana@gmail.com: remove the placeholder user in Prepzo and insert the rich one from demo
    if (user.email === 'rana@gmail.com') {
      await prepzoDb.collection('users').deleteMany({ email: 'rana@gmail.com' });
      remapDoc(user);
      await prepzoDb.collection('users').insertOne(user);
      console.log('  [Replaced] Rohit (rana@gmail.com) with complete demo profile and history ID');
      usersMigrated++;
      continue;
    }

    remapDoc(user);
    await prepzoDb.collection('users').updateOne(
      { _id: user._id },
      { $set: user },
      { upsert: true }
    );
    usersMigrated++;
  }
  console.log(`✅ Users migrated: ${usersMigrated} users.\n`);

  // B. Standard Collections to migrate directly with institute remapping
  const standardCollections = [
    'subjects',
    'courses',
    'batches',
    'liveclasses',
    'classschedules',
    'questioncategories',
    'questionchapters',
    'questiontopics',
    'questionbanks',
    'onlineexams',
    'examquestions',
    'examsubmissions',
    'doubts',
    'resources',
    'banners',
    'performanceflags',
    'proctoringlogs',
    'practicesessions',
    'feerecords',
    'paymenttransactions',
    'notifications',
    'systemconfigs',
    'mentors',
    'mentorsessions',
    'leaverequests',
    'pushdevices',
    'attendances'
  ];

  for (const colName of standardCollections) {
    const docs = await demoDb.collection(colName).find().toArray();
    if (docs.length === 0) continue;

    let count = 0;
    for (const doc of docs) {
      remapDoc(doc);
      await prepzoDb.collection(colName).updateOne(
        { _id: doc._id },
        { $set: doc },
        { upsert: true }
      );
      count++;
    }
    console.log(`✅ ${colName.padEnd(22)}: ${count} docs migrated.`);
  }

  console.log('\n==================================================');
  console.log('🎉 ALL DATA MIGRATED SUCCESSFULLY TO prepzo=Cluster0!');
  console.log('==================================================\n');

  // Print final summary
  console.log('--- FINAL PREPZO STATS ---');
  for (const colName of ['institutes', 'users', 'courses', 'batches', 'subjects', 'liveclasses', 'classschedules', 'onlineexams', 'examquestions', 'examsubmissions', 'questionbanks', 'resources', 'doubts', 'feerecords']) {
    const c = await prepzoDb.collection(colName).countDocuments();
    console.log(`  ${colName.padEnd(20)}: ${c} docs`);
  }

  await mongoose.disconnect();
}

migrate().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
