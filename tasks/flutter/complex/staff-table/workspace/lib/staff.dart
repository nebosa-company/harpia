/// Staff roster data. Do not modify this file.
class StaffMember {
  const StaffMember(this.name, this.department, this.salary);

  final String name;
  final String department;
  final int salary;
}

const List<StaffMember> staffRoster = [
  StaffMember('Imre Fodor', 'Engineering', 72000),
  StaffMember('Sana Qureshi', 'Design', 61000),
  StaffMember('Beatriz Lima', 'Engineering', 68000),
  StaffMember('Owen Whitfield', 'Sales', 48000),
  StaffMember('Yuki Tanabe', 'Design', 64000),
  StaffMember('Marta Kowalska', 'Support', 41000),
  StaffMember('Dmitri Volkov', 'Engineering', 81000),
  StaffMember('Aicha Benali', 'Sales', 52000),
  StaffMember('Lars Nyström', 'Support', 43000),
  StaffMember('Priya Raman', 'Engineering', 76000),
  StaffMember('Tomás Herrera', 'Design', 58000),
  StaffMember('Grace Okafor', 'Sales', 55000),
];
