require('dotenv').config();
const mongoose = require('mongoose');

const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lms-platform';

async function cleanup() {
  console.log('Connecting to MongoDB cluster...');
  await mongoose.connect(uri);
  const db = mongoose.connection.client.db('prepzo=Cluster0');

  console.log('=== STARTING CLEANUP IN prepzo=Cluster0 ===\n');

  // 1. Delete all teachers, students, and parents (keep admin prepzo333@gmail.com)
  const delUsersResult = await db.collection('users').deleteMany({
    role: { $in: ['teacher', 'student', 'parent'] }
  });
  console.log('✅ Deleted teachers, students, and parents from users:', delUsersResult.deletedCount);

  // 2. Delete all doubts
  const delDoubtsResult = await db.collection('doubts').deleteMany({});
  console.log('✅ Deleted doubts:', delDoubtsResult.deletedCount);

  // 3. Delete student-specific activity records (submissions, practice, fee, attendance)
  const delSubmissions = await db.collection('examsubmissions').deleteMany({});
  console.log('✅ Deleted exam submissions:', delSubmissions.deletedCount);

  const delPractice = await db.collection('practicesessions').deleteMany({});
  console.log('✅ Deleted practice sessions:', delPractice.deletedCount);

  const delFees = await db.collection('feerecords').deleteMany({});
  console.log('✅ Deleted fee records:', delFees.deletedCount);

  const delPayments = await db.collection('paymenttransactions').deleteMany({});
  console.log('✅ Deleted payment transactions:', delPayments.deletedCount);

  const delAttendance = await db.collection('attendances').deleteMany({});
  console.log('✅ Deleted attendances:', delAttendance.deletedCount);

  const delProctoring = await db.collection('proctoringlogs').deleteMany({});
  console.log('✅ Deleted proctoring logs:', delProctoring.deletedCount);

  // 4. Reset students array and teacher in batches
  const updateBatches = await db.collection('batches').updateMany(
    {},
    { $set: { students: [], batchTeacherId: null } }
  );
  console.log('✅ Reset students & teacher references in batches:', updateBatches.modifiedCount);

  // 5. Verify remaining users
  const remainingUsers = await db.collection('users').find().toArray();
  console.log('\n=== REMAINING USERS IN prepzo=Cluster0 ===');
  console.log(remainingUsers.map(u => ({ id: u._id, email: u.email, role: u.role, firstName: u.firstName })));

  // 6. Verify kept collections
  console.log('\n=== KEPT DATA IN PREPZO ===');
  for (const c of [
    'courses',
    'batches',
    'subjects',
    'questionbanks',
    'questionchapters',
    'questiontopics',
    'questioncategories',
    'onlineexams',
    'examquestions',
    'resources',
    'banners',
    'liveclasses',
    'classschedules',
    'institutes'
  ]) {
    const count = await db.collection(c).countDocuments();
    console.log('  ' + c.padEnd(22) + ': ' + count + ' docs');
  }

  await mongoose.disconnect();
  console.log('\nCleanup finished successfully.');
}

cleanup().catch(err => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
