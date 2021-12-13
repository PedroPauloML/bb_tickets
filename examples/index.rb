require_relative('../bb_tickets.rb')

bb = BBTickets.new(
  'd27bc77908ffabb01362e17d10050f56b971a5be',
  'Basic ZXlKcFpDSTZJalV5WVRVeVl6VXRZekF3TkMwMFlpSXNJbU52WkdsbmIxQjFZbXhwWTJGa2IzSWlPakFzSW1OdlpHbG5iMU52Wm5SM1lYSmxJam95TlRZMk15d2ljMlZ4ZFdWdVkybGhiRWx1YzNSaGJHRmpZVzhpT2pGOTpleUpwWkNJNklqa3hOek0xWldFdE5EZzVZeTAwTmprMkxXRTRORGt0TkdaaFlpSXNJbU52WkdsbmIxQjFZbXhwWTJGa2IzSWlPakFzSW1OdlpHbG5iMU52Wm5SM1lYSmxJam95TlRZMk15d2ljMlZ4ZFdWdVkybGhiRWx1YzNSaGJHRmpZVzhpT2pFc0luTmxjWFZsYm1OcFlXeERjbVZrWlc1amFXRnNJam94TENKaGJXSnBaVzUwWlNJNkltaHZiVzlzYjJkaFkyRnZJaXdpYVdGMElqb3hOak0zTnpZMk16Z3dNakEyZlE=',
  verbose: true
)

status = 'A'
beneficiary_agency = 452
beneficiary_account = 123873
filters = {
  dataInicioRegistro: Date.today.strftime('%d.%m.%Y')
}

begin
  tickets = bb.index(status, beneficiary_agency, beneficiary_account, filters)
rescue => ex
  puts "[ERROR] #{ex.message}"
end

puts "Tickets: #{tickets}"