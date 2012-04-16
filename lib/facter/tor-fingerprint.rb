Facter.add("tor_fingerprint") do
		setcode do
				%x{cat /var/lib/tor/fingerprint | cut -d " " -f 2}.chomp
		end
end
